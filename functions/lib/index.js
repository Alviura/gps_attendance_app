"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.markAttendance = exports.endSession = exports.startSession = exports.joinClassByCode = exports.createClass = exports.completeLecturerRegistration = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
admin.initializeApp();
const db = admin.firestore();
/** Honor-system: lecturers may act unless explicitly rejected in Firestore. */
function assertActiveLecturer(user) {
    if (user?.role !== 'lecturer' || user?.lecturerStatus === 'rejected') {
        throw new https_1.HttpsError('permission-denied', 'Only lecturers can perform this action (account may be rejected).');
    }
}
const LECTURER_REG_MIN = 4;
const LECTURER_REG_MAX = 24;
function normalizeLecturerRegNo(raw) {
    if (typeof raw !== 'string') {
        return '';
    }
    const trimmed = raw.trim().toUpperCase().replace(/\s+/g, '');
    if (trimmed.length < LECTURER_REG_MIN ||
        trimmed.length > LECTURER_REG_MAX ||
        !/^[A-Z0-9\-]+$/.test(trimmed)) {
        return '';
    }
    return trimmed;
}
/** Creates users/{uid} + claims unique lecturer_registrations/{key} (transaction). */
exports.completeLecturerRegistration = (0, https_1.onCall)({ region: 'us-central1' }, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError('unauthenticated', 'Sign in first.');
    }
    const { name, email, lecturerRegNo } = request.data ?? {};
    if (typeof name !== 'string' || name.trim().length < 2) {
        throw new https_1.HttpsError('invalid-argument', 'name is required (at least 2 characters).');
    }
    if (typeof email !== 'string' || !email.includes('@')) {
        throw new https_1.HttpsError('invalid-argument', 'A valid email is required.');
    }
    const key = normalizeLecturerRegNo(lecturerRegNo);
    if (!key) {
        throw new https_1.HttpsError('invalid-argument', `Lecturer registration number must be ${LECTURER_REG_MIN}-${LECTURER_REG_MAX} characters (letters, digits, hyphen only).`);
    }
    const claimRef = db.collection('lecturer_registrations').doc(key);
    const userRef = db.collection('users').doc(uid);
    try {
        await db.runTransaction(async (tx) => {
            const claimSnap = await tx.get(claimRef);
            const userSnap = await tx.get(userRef);
            if (claimSnap.exists) {
                const owner = claimSnap.data()?.uid;
                if (owner && owner !== uid) {
                    throw new https_1.HttpsError('already-exists', 'This lecturer registration number is already taken. Choose another.');
                }
            }
            if (userSnap.exists) {
                const u = userSnap.data();
                if (u.role === 'student') {
                    throw new https_1.HttpsError('failed-precondition', 'This account is already registered as a student.');
                }
                if (u.role === 'lecturer' &&
                    typeof u.lecturerRegNo === 'string' &&
                    normalizeLecturerRegNo(u.lecturerRegNo) !== key) {
                    throw new https_1.HttpsError('failed-precondition', 'This account is already linked to a different lecturer registration number.');
                }
            }
            tx.set(claimRef, {
                uid,
                lecturerRegNo: key,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
            });
            const userPayload = {
                name: name.trim(),
                email: email.trim(),
                role: 'lecturer',
                lecturerStatus: 'active',
                lecturerRegNo: key,
                matricNumber: null,
                updatedAt: firestore_1.FieldValue.serverTimestamp(),
            };
            if (!userSnap.exists) {
                userPayload.enrolledClassIds = [];
                userPayload.createdAt = firestore_1.FieldValue.serverTimestamp();
            }
            tx.set(userRef, userPayload, { merge: true });
        });
    }
    catch (e) {
        if (e instanceof https_1.HttpsError) {
            throw e;
        }
        throw new https_1.HttpsError('internal', String(e));
    }
    return { ok: true, lecturerRegNo: key };
});
function randomJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let s = '';
    for (let i = 0; i < 6; i++) {
        s += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return s;
}
exports.createClass = (0, https_1.onCall)({ region: 'us-central1' }, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError('unauthenticated', 'Sign in first.');
    }
    const userSnap = await db.collection('users').doc(uid).get();
    const user = userSnap.data();
    assertActiveLecturer(user);
    const { title, roomName, latitude, longitude, radiusMeters } = request.data;
    if (typeof title !== 'string' ||
        typeof roomName !== 'string' ||
        typeof latitude !== 'number' ||
        typeof longitude !== 'number') {
        throw new https_1.HttpsError('invalid-argument', 'title, roomName, latitude, and longitude are required.');
    }
    let joinCode = randomJoinCode();
    for (let attempt = 0; attempt < 5; attempt++) {
        const dup = await db
            .collection('classes')
            .where('joinCode', '==', joinCode)
            .limit(1)
            .get();
        if (dup.empty) {
            break;
        }
        joinCode = randomJoinCode();
    }
    const ref = db.collection('classes').doc();
    await ref.set({
        title,
        roomName,
        latitude,
        longitude,
        radiusMeters: typeof radiusMeters === 'number' ? radiusMeters : 50,
        lecturerId: uid,
        lecturerName: user?.name ?? 'Lecturer',
        joinCode,
        enrolledStudentIds: [],
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return { classId: ref.id, joinCode };
});
exports.joinClassByCode = (0, https_1.onCall)({ region: 'us-central1' }, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError('unauthenticated', 'Sign in first.');
    }
    const { joinCode } = request.data;
    if (typeof joinCode !== 'string' || joinCode.trim().length === 0) {
        throw new https_1.HttpsError('invalid-argument', 'joinCode is required.');
    }
    const userSnap = await db.collection('users').doc(uid).get();
    const user = userSnap.data();
    if (user?.role !== 'student') {
        throw new https_1.HttpsError('failed-precondition', 'Only student accounts can join a class.');
    }
    const code = joinCode.trim().toUpperCase();
    const snap = await db
        .collection('classes')
        .where('joinCode', '==', code)
        .limit(1)
        .get();
    if (snap.empty) {
        throw new https_1.HttpsError('not-found', 'No class matches this join code.');
    }
    const classDoc = snap.docs[0];
    const classId = classDoc.id;
    await db.runTransaction(async (transaction) => {
        const classRef = db.collection('classes').doc(classId);
        const userRef = db.collection('users').doc(uid);
        transaction.update(classRef, {
            enrolledStudentIds: firestore_1.FieldValue.arrayUnion(uid),
        });
        transaction.update(userRef, {
            enrolledClassIds: firestore_1.FieldValue.arrayUnion(classId),
        });
    });
    const c = classDoc.data();
    return { classId, title: c.title ?? 'Class' };
});
exports.startSession = (0, https_1.onCall)({ region: 'us-central1' }, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError('unauthenticated', 'Sign in first.');
    }
    const userSnap = await db.collection('users').doc(uid).get();
    const user = userSnap.data();
    assertActiveLecturer(user);
    const { classId, title, durationMinutes } = request.data;
    if (typeof classId !== 'string') {
        throw new https_1.HttpsError('invalid-argument', 'classId is required.');
    }
    const classRef = db.collection('classes').doc(classId);
    const classSnap = await classRef.get();
    if (!classSnap.exists) {
        throw new https_1.HttpsError('not-found', 'Class not found.');
    }
    const classData = classSnap.data();
    if (classData.lecturerId !== uid) {
        throw new https_1.HttpsError('permission-denied', 'You do not own this class.');
    }
    const enrolled = classData.enrolledStudentIds ?? [];
    const now = firestore_1.Timestamp.now();
    const duration = typeof durationMinutes === 'number' ? durationMinutes : 120;
    const ends = firestore_1.Timestamp.fromMillis(now.toMillis() + duration * 60 * 1000);
    const sessRef = db.collection('sessions').doc();
    await sessRef.set({
        classId,
        lecturerId: uid,
        title: typeof title === 'string' ? title : classData.title ?? 'Session',
        status: 'active',
        startsAt: now,
        endsAt: ends,
        enrolledStudentIds: [...enrolled],
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return { sessionId: sessRef.id };
});
exports.endSession = (0, https_1.onCall)({ region: 'us-central1' }, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError('unauthenticated', 'Sign in first.');
    }
    const { sessionId } = request.data;
    if (typeof sessionId !== 'string') {
        throw new https_1.HttpsError('invalid-argument', 'sessionId is required.');
    }
    const sessionRef = db.collection('sessions').doc(sessionId);
    const sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists) {
        throw new https_1.HttpsError('not-found', 'Session not found.');
    }
    const session = sessionSnap.data();
    const classId = session.classId;
    if (!classId) {
        throw new https_1.HttpsError('failed-precondition', 'Session has no class.');
    }
    const classSnap = await db.collection('classes').doc(classId).get();
    const classData = classSnap.data();
    if (classData?.lecturerId !== uid) {
        throw new https_1.HttpsError('permission-denied', 'You do not own this session.');
    }
    await sessionRef.update({
        status: 'closed',
        closedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return { ok: true };
});
exports.markAttendance = (0, https_1.onCall)({ region: 'us-central1' }, async (request) => {
    const studentId = request.auth?.uid;
    if (!studentId) {
        throw new https_1.HttpsError('unauthenticated', 'Sign in before marking attendance.');
    }
    const { sessionId, latitude, longitude, verificationMethod } = request.data;
    if (!sessionId || typeof latitude !== 'number' || typeof longitude !== 'number') {
        throw new https_1.HttpsError('invalid-argument', 'Session ID and GPS coordinates are required.');
    }
    if (verificationMethod !== 'biometric') {
        throw new https_1.HttpsError('failed-precondition', 'Biometric verification is required.');
    }
    const sessionRef = db.collection('sessions').doc(sessionId);
    const sessionSnap = await sessionRef.get();
    if (!sessionSnap.exists) {
        throw new https_1.HttpsError('not-found', 'Class session was not found.');
    }
    const session = sessionSnap.data();
    if (session.status !== 'active') {
        throw new https_1.HttpsError('failed-precondition', 'Attendance is not open for this session.');
    }
    const now = firestore_1.Timestamp.now();
    if (session.startsAt && now.toMillis() < session.startsAt.toMillis()) {
        throw new https_1.HttpsError('failed-precondition', 'Attendance has not started yet.');
    }
    if (session.endsAt && now.toMillis() > session.endsAt.toMillis()) {
        throw new https_1.HttpsError('failed-precondition', 'Attendance has already closed.');
    }
    if (!session.classId) {
        throw new https_1.HttpsError('failed-precondition', 'Session is missing class information.');
    }
    const classSnap = await db.collection('classes').doc(session.classId).get();
    if (!classSnap.exists) {
        throw new https_1.HttpsError('not-found', 'Class record was not found.');
    }
    const classRecord = classSnap.data();
    const sessionEnrolled = session.enrolledStudentIds;
    const enrolledStudents = classRecord.enrolledStudentIds ?? [];
    const allowed = sessionEnrolled && sessionEnrolled.length > 0
        ? sessionEnrolled.includes(studentId)
        : enrolledStudents.includes(studentId);
    if (!allowed) {
        throw new https_1.HttpsError('permission-denied', 'Student is not enrolled in this class.');
    }
    if (typeof classRecord.latitude !== 'number' ||
        typeof classRecord.longitude !== 'number') {
        throw new https_1.HttpsError('failed-precondition', 'Classroom GPS coordinates are missing.');
    }
    const radiusMeters = classRecord.radiusMeters ?? 50;
    const distanceMeters = distanceBetweenMeters(latitude, longitude, classRecord.latitude, classRecord.longitude);
    if (distanceMeters > radiusMeters) {
        return {
            accepted: false,
            distanceMeters,
            message: `Attendance rejected. You are ${distanceMeters.toFixed(1)}m away, ` +
                `outside the ${radiusMeters.toFixed(0)}m classroom radius.`,
        };
    }
    const attendanceId = `${sessionId}_${studentId}`;
    const attendanceRef = db.collection('attendance').doc(attendanceId);
    const reportRef = db.collection('reports').doc(sessionId);
    await db.runTransaction(async (transaction) => {
        const attendanceSnap = await transaction.get(attendanceRef);
        if (attendanceSnap.exists) {
            throw new https_1.HttpsError('already-exists', 'Attendance has already been marked.');
        }
        const reportSnap = await transaction.get(reportRef);
        const previousPresent = reportSnap.data()?.presentCount;
        const nextPresent = (typeof previousPresent === 'number' ? previousPresent : 0) + 1;
        const totalStudents = sessionEnrolled && sessionEnrolled.length > 0
            ? sessionEnrolled.length
            : enrolledStudents.length;
        transaction.set(attendanceRef, {
            sessionId,
            classId: session.classId,
            studentId,
            markedAt: firestore_1.FieldValue.serverTimestamp(),
            latitude,
            longitude,
            distanceMeters,
            verificationMethod: 'biometric',
            status: 'present',
        });
        transaction.set(reportRef, {
            sessionId,
            classId: session.classId,
            sessionTitle: classRecord.title ?? 'Class session',
            totalStudents,
            presentCount: nextPresent,
            absentCount: Math.max(totalStudents - nextPresent, 0),
            generatedAt: firestore_1.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
    return {
        accepted: true,
        distanceMeters,
        message: `Attendance accepted. You are ${distanceMeters.toFixed(1)}m from the classroom.`,
    };
});
function distanceBetweenMeters(latitudeA, longitudeA, latitudeB, longitudeB) {
    const earthRadiusMeters = 6371000;
    const latA = toRadians(latitudeA);
    const latB = toRadians(latitudeB);
    const deltaLat = toRadians(latitudeB - latitudeA);
    const deltaLng = toRadians(longitudeB - longitudeA);
    const haversine = Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
        Math.cos(latA) *
            Math.cos(latB) *
            Math.sin(deltaLng / 2) *
            Math.sin(deltaLng / 2);
    return earthRadiusMeters * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
}
function toRadians(degrees) {
    return degrees * (Math.PI / 180);
}
//# sourceMappingURL=index.js.map