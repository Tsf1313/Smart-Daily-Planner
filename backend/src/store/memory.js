const { randomUUID } = require("node:crypto");

function toTimestamp(date) {
  return new Date(date).toISOString();
}

function addDays(dateString, days) {
  const date = new Date(`${dateString}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function malaysiaIso(date, time) {
  return new Date(`${date}T${time}:00+08:00`).toISOString();
}

class MemoryStore {
  constructor() {
    this.profiles = new Map();
    this.entries = new Map();
    this.occurrences = new Map();
    this.photos = new Map();
    this.actions = [];
    this.facilities = new Map([
      ["sample-library", {
        id: "sample-library",
        name: "Sample Campus Library",
        latitude: 2.3,
        longitude: 111.8,
        isActive: true,
        isSample: true,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }],
    ]);
  }

  async getOrCreateProfile(claims) {
    let profile = [...this.profiles.values()].find((item) => item.firebaseUid === claims.firebaseUid);
    if (!profile) {
      profile = {
        id: randomUUID(),
        firebaseUid: claims.firebaseUid,
        name: claims.name || "Student",
        email: claims.email || "",
        role: "student",
        status: "active",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
      this.profiles.set(profile.id, profile);
    }
    return { ...profile };
  }

  async updateProfile(id, fields) {
    const profile = this.profiles.get(id);
    Object.assign(profile, fields, { updatedAt: new Date().toISOString() });
    return { ...profile };
  }

  serializeEntry(entry) {
    return { ...entry };
  }

  generateOccurrences(entry) {
    if (entry.kind !== "routine") return [];
    const from = entry.startDate;
    const to = entry.repeatUntil || addDays(from, 366);
    const generated = [];
    for (let date = from; date <= to; date = addDays(date, 1)) {
      const weekday = (new Date(`${date}T00:00:00Z`).getUTCDay() + 6) % 7 + 1;
      const matches =
        entry.repeat === "none" ? date === from :
        entry.repeat === "daily" ? true :
        entry.repeat === "weekly" ? entry.weekdays.includes(weekday) : false;
      if (!matches) continue;
      const existing = [...this.occurrences.values()].find((item) => item.entryId === entry.id && item.date === date);
      const occurrence = existing || {
        id: randomUUID(),
        entryId: entry.id,
        date,
        startAt: malaysiaIso(date, entry.startTime),
        endAt: malaysiaIso(date, entry.endTime),
        isCompleted: false,
      };
      occurrence.startAt = malaysiaIso(date, entry.startTime);
      occurrence.endAt = malaysiaIso(date, entry.endTime);
      this.occurrences.set(occurrence.id, occurrence);
      generated.push(occurrence);
    }
    return generated;
  }

  async createEntry(ownerId, value) {
    const now = new Date().toISOString();
    const entry = {
      id: randomUUID(),
      ownerId,
      ...value,
      isCompleted: value.kind === "deadline" ? false : undefined,
      createdAt: now,
      updatedAt: now,
    };
    if (entry.kind === "routine") delete entry.isCompleted;
    if (entry.location === undefined) entry.location = null;
    if (entry.photoId === undefined) entry.photoId = null;
    if (entry.description === undefined) entry.description = null;
    if (entry.reminderMinutes === undefined) entry.reminderMinutes = null;
    this.entries.set(entry.id, entry);
    this.generateOccurrences(entry);
    return this.serializeEntry(entry);
  }

  async getEntry(ownerId, id) {
    const entry = this.entries.get(id);
    return entry && entry.ownerId === ownerId ? this.serializeEntry(entry) : null;
  }

  async listEntries(ownerId, range, paging) {
    let items = [...this.entries.values()].filter((entry) => entry.ownerId === ownerId);
    items = items.filter((entry) => {
      if (entry.kind === "deadline") return entry.dueAt >= range.from && entry.dueAt < range.to;
      return entry.startDate < range.to.slice(0, 10) &&
        (!entry.repeatUntil || entry.repeatUntil >= range.from.slice(0, 10));
    });
    const total = items.length;
    const start = (paging.page - 1) * paging.pageSize;
    items = items.slice(start, start + paging.pageSize).map((entry) => this.serializeEntry(entry));
    return { items, page: paging.page, pageSize: paging.pageSize, total };
  }

  async updateEntry(ownerId, id, fields) {
    const entry = this.entries.get(id);
    if (!entry || entry.ownerId !== ownerId) return null;
    if (fields.location === null) entry.location = null;
    if (fields.photoId === null) entry.photoId = null;
    Object.assign(entry, fields, { updatedAt: new Date().toISOString() });
    if (entry.kind === "routine") this.generateOccurrences(entry);
    return this.serializeEntry(entry);
  }

  async deleteEntry(ownerId, id) {
    const entry = this.entries.get(id);
    if (!entry || entry.ownerId !== ownerId) return false;
    this.entries.delete(id);
    for (const [occurrenceId, occurrence] of this.occurrences) {
      if (occurrence.entryId === id) this.occurrences.delete(occurrenceId);
    }
    return true;
  }

  async setDeadlineCompletion(ownerId, id, isCompleted) {
    const entry = this.entries.get(id);
    if (!entry || entry.ownerId !== ownerId || entry.kind !== "deadline") return null;
    entry.isCompleted = isCompleted;
    entry.updatedAt = new Date().toISOString();
    return this.serializeEntry(entry);
  }

  async listOccurrences(ownerId, range) {
    const from = range.from.slice(0, 10);
    const to = range.to.slice(0, 10);
    const ownedIds = new Set([...this.entries.values()].filter((entry) => entry.ownerId === ownerId).map((entry) => entry.id));
    for (const entry of this.entries.values()) {
      if (entry.ownerId === ownerId && entry.kind === "routine") this.generateOccurrences(entry);
    }
    return [...this.occurrences.values()].filter((item) =>
      ownedIds.has(item.entryId) && item.date >= from && item.date < to,
    ).sort((a, b) => a.startAt.localeCompare(b.startAt)).map((item) => ({ ...item }));
  }

  async setOccurrenceCompletion(ownerId, id, isCompleted) {
    const occurrence = this.occurrences.get(id);
    if (!occurrence) return null;
    const entry = this.entries.get(occurrence.entryId);
    if (!entry || entry.ownerId !== ownerId) return null;
    occurrence.isCompleted = isCompleted;
    return { ...occurrence };
  }

  haversine(latitude, longitude, facility) {
    const radius = 6371000;
    const toRadians = (degrees) => degrees * Math.PI / 180;
    const dLat = toRadians(facility.latitude - latitude);
    const dLon = toRadians(facility.longitude - longitude);
    const a = Math.sin(dLat / 2) ** 2 +
      Math.cos(toRadians(latitude)) * Math.cos(toRadians(facility.latitude)) * Math.sin(dLon / 2) ** 2;
    return radius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  async listFacilities(query) {
    const latitude = Number(query.latitude);
    const longitude = Number(query.longitude);
    const radius = query.radiusMeters === undefined ? 5000 : Number(query.radiusMeters);
    if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 ||
        !Number.isFinite(longitude) || longitude < -180 || longitude > 180 ||
        !Number.isFinite(radius) || radius < 1 || radius > 50000) return [];
    return [...this.facilities.values()].filter((item) => item.isActive)
      .map((item) => {
        const distanceMeters = Math.round(this.haversine(latitude, longitude, item));
        return { facilityId: item.id, name: item.name, latitude: item.latitude, longitude: item.longitude, distanceMeters };
      })
      .filter((item) => item.distanceMeters <= radius)
      .sort((a, b) => a.distanceMeters - b.distanceMeters);
  }

  async createPhoto(ownerId, file) {
    const id = randomUUID();
    const photo = {
      id,
      ownerId,
      mimeType: file.mimetype,
      data: Buffer.from(file.buffer),
      sizeBytes: file.size,
      createdAt: new Date().toISOString(),
    };
    this.photos.set(id, photo);
    return { id, mimeType: photo.mimeType, sizeBytes: photo.sizeBytes, createdAt: photo.createdAt };
  }

  async getPhoto(ownerId, id) {
    const photo = this.photos.get(id);
    return photo && photo.ownerId === ownerId ? photo : null;
  }

  async deletePhoto(ownerId, id) {
    const photo = this.photos.get(id);
    if (!photo || photo.ownerId !== ownerId) return false;
    for (const entry of this.entries.values()) {
      if (entry.ownerId === ownerId && entry.photoId === id) return false;
    }
    this.photos.delete(id);
    return true;
  }

  async listUsers(query, actingProfile) {
    const search = String(query.search || "").toLowerCase();
    let items = [...this.profiles.values()];
    if (search) items = items.filter((item) => item.name.toLowerCase().includes(search) || item.email.toLowerCase().includes(search));
    const page = Number(query.page || 1);
    const pageSize = Number(query.pageSize || 20);
    const total = items.length;
    const start = (page - 1) * pageSize;
    return { items: items.slice(start, start + pageSize).map((item) => ({ ...item })), page, pageSize, total };
  }

  async setUserStatus(id, status, actingProfile) {
    const profile = this.profiles.get(id);
    if (!profile) return null;
    profile.status = status;
    profile.updatedAt = new Date().toISOString();
    this.actions.push({
      id: randomUUID(),
      actingAdminId: actingProfile.id,
      targetType: "user",
      targetId: id,
      action: status === "suspended" ? "SUSPEND_USER" : "REACTIVATE_USER",
      timestamp: new Date().toISOString(),
    });
    return { ...profile };
  }

  async listAdminFacilities(query) {
    let items = [...this.facilities.values()];
    if (query.active === "true") items = items.filter((item) => item.isActive);
    if (query.active === "false") items = items.filter((item) => !item.isActive);
    return items.map((item) => ({ ...item }));
  }

  async createFacility(fields, actingProfile) {
    const now = new Date().toISOString();
    const facility = {
      id: randomUUID(),
      ...fields,
      isActive: fields.isActive ?? true,
      isSample: false,
      createdAt: now,
      updatedAt: now,
    };
    this.facilities.set(facility.id, facility);
    this.recordAction(actingProfile, "facility", facility.id, "CREATE_FACILITY");
    return { ...facility };
  }

  async updateFacility(id, fields, actingProfile) {
    const facility = this.facilities.get(id);
    if (!facility) return null;
    Object.assign(facility, fields, { updatedAt: new Date().toISOString() });
    this.recordAction(actingProfile, "facility", id, fields.isActive === false ? "DEACTIVATE_FACILITY" : "UPDATE_FACILITY");
    return { ...facility };
  }

  recordAction(actingProfile, targetType, targetId, action) {
    this.actions.push({
      id: randomUUID(),
      actingAdminId: actingProfile.id,
      targetType,
      targetId,
      action,
      timestamp: new Date().toISOString(),
    });
  }

  async listActions(query) {
    let items = [...this.actions];
    if (query.targetId) items = items.filter((item) => item.targetId === query.targetId);
    return items.map((item) => ({ ...item }));
  }
}

module.exports = { MemoryStore };
