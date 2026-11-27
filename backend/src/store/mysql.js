const { randomUUID } = require("node:crypto");
const fs = require("node:fs/promises");
const path = require("node:path");
const mysql = require("mysql2/promise");

const entryColumns = `
  id, owner_id AS ownerId, kind, title, description, time_zone AS timeZone,
  reminder_minutes AS reminderMinutes, location_facility_id AS locationFacilityId,
  location_name AS locationName, latitude, longitude, photo_id AS photoId,
  DATE_FORMAT(due_at, '%Y-%m-%dT%H:%i:%s.000Z') AS dueAt,
  DATE_FORMAT(due_at, '%Y-%m-%d') AS dueDate, is_completed AS isCompleted,
  DATE_FORMAT(start_date, '%Y-%m-%d') AS startDate,
  TIME_FORMAT(start_time, '%H:%i') AS startTime,
  TIME_FORMAT(end_time, '%H:%i') AS endTime,
  repeat_type AS repeatType, weekdays, DATE_FORMAT(repeat_until, '%Y-%m-%d') AS repeatUntil,
  DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s.000Z') AS createdAt,
  DATE_FORMAT(updated_at, '%Y-%m-%dT%H:%i:%s.000Z') AS updatedAt`;

function createPoolFromEnvironment() {
  if (process.env.MYSQL_URL) {
    return mysql.createPool(process.env.MYSQL_URL, { timezone: "Z", dateStrings: true });
  }
  if (!process.env.DB_HOST || !process.env.DB_USER || !process.env.DB_NAME) {
    throw Object.assign(new Error("Configure MYSQL_URL or DB_HOST, DB_USER and DB_NAME."), {
      code: "MYSQL_CONFIG_MISSING",
    });
  }
  return mysql.createPool({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 3306),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_NAME,
    timezone: "Z",
    dateStrings: true,
    connectionLimit: 10,
  });
}

function mapProfile(row) {
  return {
    id: row.id,
    firebaseUid: row.firebaseUid,
    name: row.name,
    email: row.email,
    role: row.role,
    status: row.status,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

function mapEntry(row) {
  const entry = {
    id: row.id,
    ownerId: row.ownerId,
    kind: row.kind,
    title: row.title,
    description: row.description,
    timeZone: row.timeZone,
    reminderMinutes: row.reminderMinutes === null ? null : Number(row.reminderMinutes),
    location: row.locationName === null ? null : {
      facilityId: row.locationFacilityId,
      name: row.locationName,
      latitude: row.latitude === null ? null : Number(row.latitude),
      longitude: row.longitude === null ? null : Number(row.longitude),
    },
    photoId: row.photoId,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
  if (row.kind === "deadline") {
    entry.dueAt = row.dueAt;
    entry.dueDate = row.dueDate;
    entry.isCompleted = Boolean(row.isCompleted);
  } else {
    entry.startDate = row.startDate;
    entry.startTime = row.startTime;
    entry.endTime = row.endTime;
    entry.repeat = row.repeatType;
    entry.weekdays = typeof row.weekdays === "string" ? JSON.parse(row.weekdays) : row.weekdays;
    entry.repeatUntil = row.repeatUntil;
  }
  return entry;
}

function dateTime(date, time) {
  return new Date(`${date}T${time}:00+08:00`);
}

function malaysiaToday() {
  return new Date(Date.now() + 8 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

class MysqlStore {
  constructor(pool = createPoolFromEnvironment()) {
    this.pool = pool;
    this.photoDirectory = path.resolve(process.env.PHOTO_STORAGE_DIR || "./storage/photos");
    this.pool.on("connection", (connection) => {
      connection.query("SET time_zone = '+00:00'", (error) => {
        if (error) connection.destroy();
      });
    });
  }

  async ping() {
    await this.pool.query("SELECT 1");
  }

  async close() {
    await this.pool.end();
  }

  async getOrCreateProfile(claims) {
    const id = randomUUID();
    await this.pool.execute(
      `INSERT INTO users (id, firebase_uid, name, email) VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE name = VALUES(name), email = VALUES(email)`,
      [id, claims.firebaseUid, claims.name || "Student", claims.email || ""],
    );
    const [rows] = await this.pool.execute(
      `SELECT id, firebase_uid AS firebaseUid, name, email, role, status,
              DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s.000Z') AS createdAt,
              DATE_FORMAT(updated_at, '%Y-%m-%dT%H:%i:%s.000Z') AS updatedAt
       FROM users WHERE firebase_uid = ?`,
      [claims.firebaseUid],
    );
    return mapProfile(rows[0]);
  }

  async updateProfile(id, fields) {
    await this.pool.execute("UPDATE users SET name = ? WHERE id = ?", [fields.name, id]);
    const [rows] = await this.pool.execute(
      `SELECT id, firebase_uid AS firebaseUid, name, email, role, status,
              DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s.000Z') AS createdAt,
              DATE_FORMAT(updated_at, '%Y-%m-%dT%H:%i:%s.000Z') AS updatedAt
       FROM users WHERE id = ?`,
      [id],
    );
    return mapProfile(rows[0]);
  }

  async createEntry(ownerId, value) {
    const id = randomUUID();
    const dueAt = value.dueAt ? new Date(value.dueAt) : null;
    const location = value.location || null;
    await this.pool.execute(
      `INSERT INTO entries (
        id, owner_id, kind, title, description, time_zone, reminder_minutes,
        location_facility_id, location_name, latitude, longitude, photo_id,
        due_at, is_completed, start_date, start_time, end_time, repeat_type, weekdays, repeat_until
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id, ownerId, value.kind, value.title, value.description || null,
        value.timeZone || "Asia/Kuala_Lumpur", value.reminderMinutes ?? null,
        location?.facilityId ?? null, location?.name ?? null, location?.latitude ?? null,
        location?.longitude ?? null, value.photoId ?? null, dueAt,
        value.kind === "deadline" ? false : null, value.startDate || null,
        value.startTime || null, value.endTime || null, value.repeat || null,
        value.weekdays ? JSON.stringify(value.weekdays) : null, value.repeatUntil || null,
      ],
    );
    const entry = await this.getEntry(ownerId, id);
    if (entry.kind === "routine") await this.generateOccurrences(entry);
    return entry;
  }

  async getEntry(ownerId, id) {
    const [rows] = await this.pool.execute(
      `SELECT ${entryColumns} FROM entries WHERE owner_id = ? AND id = ?`,
      [ownerId, id],
    );
    return rows.length ? mapEntry(rows[0]) : null;
  }

  async listDashboardDeadlines(ownerId) {
    const [rows] = await this.pool.execute(
      `SELECT id, title, dueDate FROM (
         SELECT e.id, e.title, DATE_FORMAT(e.due_at, '%Y-%m-%d') AS dueDate
         FROM entries e WHERE e.owner_id = ? AND e.kind = 'deadline'
         UNION ALL
         SELECT legacy.id, legacy.title, DATE_FORMAT(legacy.due_date, '%Y-%m-%d') AS dueDate
         FROM planner_deadlines legacy
         JOIN users u ON u.firebase_uid = CONVERT(legacy.owner_uid USING utf8mb4)
         WHERE u.id = ?
       ) deadlines
       ORDER BY dueDate, id`,
      [ownerId, ownerId],
    );
    return rows;
  }

  async listEntries(ownerId, range, paging) {
    const deadlineConditions = ["kind = 'deadline'"];
    const routineConditions = ["kind = 'routine'"];
    const deadlineParams = [];
    const routineParams = [];
    if (range.from) {
      deadlineConditions.push("due_at >= ?");
      routineConditions.push("(repeat_until IS NULL OR repeat_until >= DATE(?))");
      deadlineParams.push(range.from);
      routineParams.push(range.from.slice(0, 10));
    }
    if (range.to) {
      deadlineConditions.push("due_at < ?");
      routineConditions.push("start_date < DATE(?)");
      deadlineParams.push(range.to);
      routineParams.push(range.to.slice(0, 10));
    }
    const where = `owner_id = ? AND ((${deadlineConditions.join(" AND ")}) OR (${routineConditions.join(" AND ")}))`;
    const params = [ownerId, ...deadlineParams, ...routineParams];
    const [countRows] = await this.pool.execute(
      `SELECT COUNT(*) AS total FROM entries WHERE ${where}`,
      params,
    );
    const [rows] = await this.pool.execute(
      `SELECT ${entryColumns} FROM entries WHERE ${where}
       ORDER BY COALESCE(due_at, start_date), id LIMIT ? OFFSET ?`,
      [...params, paging.pageSize, (paging.page - 1) * paging.pageSize],
    );
    return {
      items: rows.map(mapEntry),
      page: paging.page,
      pageSize: paging.pageSize,
      total: Number(countRows[0].total),
    };
  }

  async updateEntry(ownerId, id, fields) {
    const columns = {
      title: "title",
      description: "description",
      timeZone: "time_zone",
      reminderMinutes: "reminder_minutes",
      photoId: "photo_id",
      dueAt: "due_at",
      startDate: "start_date",
      startTime: "start_time",
      endTime: "end_time",
      repeat: "repeat_type",
      weekdays: "weekdays",
      repeatUntil: "repeat_until",
    };
    const sets = [];
    const params = [];
    for (const [field, column] of Object.entries(columns)) {
      if (fields[field] === undefined || (field === "dueAt" && fields.dueDate !== undefined)) continue;
      sets.push(`${column} = ?`);
      if (field === "dueAt") params.push(new Date(fields[field]));
      else params.push(field === "weekdays" && fields[field] !== null ? JSON.stringify(fields[field]) : fields[field]);
    }
    if (fields.dueDate !== undefined) {
      sets.push("due_at = ?");
      params.push(new Date(`${fields.dueDate}T00:00:00.000Z`));
    }
    if (fields.location !== undefined) {
      const location = fields.location;
      sets.push("location_facility_id = ?", "location_name = ?", "latitude = ?", "longitude = ?");
      params.push(location?.facilityId ?? null, location?.name ?? null, location?.latitude ?? null, location?.longitude ?? null);
    }
    if (sets.length) {
      params.push(ownerId, id);
      await this.pool.execute(
        `UPDATE entries SET ${sets.join(", ")}, updated_at = CURRENT_TIMESTAMP(3) WHERE owner_id = ? AND id = ?`,
        params,
      );
    }
    const entry = await this.getEntry(ownerId, id);
    if (entry?.kind === "routine") await this.generateOccurrences(entry);
    return entry;
  }

  async deleteEntry(ownerId, id) {
    const [result] = await this.pool.execute("DELETE FROM entries WHERE owner_id = ? AND id = ?", [ownerId, id]);
    return result.affectedRows > 0;
  }

  async setDeadlineCompletion(ownerId, id, isCompleted) {
    await this.pool.execute(
      "UPDATE entries SET is_completed = ? WHERE owner_id = ? AND id = ? AND kind = 'deadline'",
      [isCompleted, ownerId, id],
    );
    const entry = await this.getEntry(ownerId, id);
    return entry?.kind === "deadline" ? entry : null;
  }

  async generateOccurrences(entry) {
    if (entry.kind !== "routine") return;
    const until = entry.repeatUntil || (() => {
      const date = new Date(`${entry.startDate}T00:00:00.000Z`);
      date.setUTCDate(date.getUTCDate() + 366);
      return date.toISOString().slice(0, 10);
    })();
    const dates = [];
    for (let date = entry.startDate; date <= until; ) {
      const weekday = (new Date(`${date}T00:00:00.000Z`).getUTCDay() + 6) % 7 + 1;
      const matches = entry.repeat === "none" ? date === entry.startDate
        : entry.repeat === "daily" || (entry.repeat === "weekly" && entry.weekdays.includes(weekday));
      if (matches) {
        dates.push(date);
        await this.pool.execute(
          `INSERT INTO routine_occurrences (id, entry_id, occurrence_date, start_at, end_at)
           VALUES (?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE
             start_at = IF(is_completed, start_at, VALUES(start_at)),
             end_at = IF(is_completed, end_at, VALUES(end_at))`,
          [
            randomUUID(), entry.id, date,
            dateTime(date, entry.startTime), dateTime(date, entry.endTime),
          ],
        );
      }
      const next = new Date(`${date}T00:00:00.000Z`);
      next.setUTCDate(next.getUTCDate() + 1);
      date = next.toISOString().slice(0, 10);
    }
    const staleParams = [entry.id, malaysiaToday()];
    const staleDates = dates.length
      ? ` AND occurrence_date NOT IN (${dates.map(() => "?").join(", ")})`
      : "";
    staleParams.push(...dates);
    await this.pool.execute(
      `DELETE FROM routine_occurrences
       WHERE entry_id = ? AND occurrence_date >= ? AND is_completed = FALSE${staleDates}`,
      staleParams,
    );
  }

  async listOccurrences(ownerId, range) {
    const [entries] = await this.pool.execute(
      `SELECT ${entryColumns} FROM entries WHERE owner_id = ? AND kind = 'routine'`,
      [ownerId],
    );
    for (const row of entries) await this.generateOccurrences(mapEntry(row));
    const [rows] = await this.pool.execute(
      `SELECT o.id, o.entry_id AS entryId,
              DATE_FORMAT(o.occurrence_date, '%Y-%m-%d') AS date,
              DATE_FORMAT(o.start_at, '%Y-%m-%dT%H:%i:%s.000Z') AS startAt,
              DATE_FORMAT(o.end_at, '%Y-%m-%dT%H:%i:%s.000Z') AS endAt,
              o.is_completed AS isCompleted
       FROM routine_occurrences o
       JOIN entries e ON e.id = o.entry_id
       WHERE e.owner_id = ? AND o.occurrence_date >= DATE(?) AND o.occurrence_date < DATE(?)
       ORDER BY o.start_at`,
      [ownerId, range.from.slice(0, 10), range.to.slice(0, 10)],
    );
    return rows.map((row) => ({ ...row, isCompleted: Boolean(row.isCompleted) }));
  }

  async setOccurrenceCompletion(ownerId, id, isCompleted) {
    await this.pool.execute(
      `UPDATE routine_occurrences o JOIN entries e ON e.id = o.entry_id
       SET o.is_completed = ? WHERE o.id = ? AND e.owner_id = ?`,
      [isCompleted, id, ownerId],
    );
    const [rows] = await this.pool.execute(
      `SELECT o.id, o.entry_id AS entryId,
              DATE_FORMAT(o.occurrence_date, '%Y-%m-%d') AS date,
              DATE_FORMAT(o.start_at, '%Y-%m-%dT%H:%i:%s.000Z') AS startAt,
              DATE_FORMAT(o.end_at, '%Y-%m-%dT%H:%i:%s.000Z') AS endAt,
              o.is_completed AS isCompleted
       FROM routine_occurrences o JOIN entries e ON e.id = o.entry_id
       WHERE o.id = ? AND e.owner_id = ?`,
      [id, ownerId],
    );
    return rows.length ? { ...rows[0], isCompleted: Boolean(rows[0].isCompleted) } : null;
  }

  async listFacilities(query) {
    const latitude = Number(query.latitude);
    const longitude = Number(query.longitude);
    const radius = query.radiusMeters === undefined ? 5000 : Number(query.radiusMeters);
    const [rows] = await this.pool.execute(
      "SELECT id, name, latitude, longitude FROM facilities WHERE is_active = TRUE",
    );
    return rows.map((item) => ({
      facilityId: item.id,
      name: item.name,
      latitude: Number(item.latitude),
      longitude: Number(item.longitude),
      distanceMeters: Math.round(this.haversine(latitude, longitude, item)),
    })).filter((item) => item.distanceMeters <= radius)
      .sort((a, b) => a.distanceMeters - b.distanceMeters);
  }

  async createPhoto(ownerId, file) {
    const id = randomUUID();
    const extension = file.mimetype === "image/png" ? ".png" : ".jpg";
    await fs.mkdir(this.photoDirectory, { recursive: true });
    const storagePath = path.join(this.photoDirectory, `${id}${extension}`);
    await fs.writeFile(storagePath, file.buffer, { flag: "wx" });
    try {
      await this.pool.execute(
        "INSERT INTO photos (id, owner_id, mime_type, storage_path, size_bytes) VALUES (?, ?, ?, ?, ?)",
        [id, ownerId, file.mimetype, storagePath, file.size],
      );
    } catch (error) {
      await fs.unlink(storagePath);
      throw error;
    }
    return { id, mimeType: file.mimetype, sizeBytes: file.size, createdAt: new Date().toISOString() };
  }

  async getPhoto(ownerId, id) {
    const [rows] = await this.pool.execute(
      "SELECT mime_type AS mimeType, storage_path AS storagePath, size_bytes AS sizeBytes, created_at AS createdAt FROM photos WHERE owner_id = ? AND id = ?",
      [ownerId, id],
    );
    if (!rows.length) return null;
    return { ...rows[0], data: await fs.readFile(rows[0].storagePath) };
  }

  async deletePhoto(ownerId, id) {
    const [entries] = await this.pool.execute(
      "SELECT id FROM entries WHERE owner_id = ? AND photo_id = ? LIMIT 1",
      [ownerId, id],
    );
    if (entries.length) return false;
    const [rows] = await this.pool.execute(
      "SELECT storage_path AS storagePath FROM photos WHERE owner_id = ? AND id = ?",
      [ownerId, id],
    );
    if (!rows.length) return false;
    await this.pool.execute("DELETE FROM photos WHERE owner_id = ? AND id = ?", [ownerId, id]);
    await fs.unlink(rows[0].storagePath);
    return true;
  }

  async listUsers(query) {
    const page = Number(query.page || 1);
    const pageSize = Number(query.pageSize || 20);
    const search = `%${String(query.search || "")}%`;
    const [countRows] = await this.pool.execute(
      "SELECT COUNT(*) AS total FROM users WHERE name LIKE ? OR email LIKE ?",
      [search, search],
    );
    const [rows] = await this.pool.execute(
      `SELECT id, firebase_uid AS firebaseUid, name, email, role, status,
              DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s.000Z') AS createdAt,
              DATE_FORMAT(updated_at, '%Y-%m-%dT%H:%i:%s.000Z') AS updatedAt
       FROM users WHERE name LIKE ? OR email LIKE ? ORDER BY name LIMIT ? OFFSET ?`,
      [search, search, pageSize, (page - 1) * pageSize],
    );
    return { items: rows.map(mapProfile), page, pageSize, total: Number(countRows[0].total) };
  }

  async setUserStatus(id, status, actingProfile) {
    const [result] = await this.pool.execute(
      "UPDATE users SET status = ? WHERE id = ?",
      [status, id],
    );
    if (!result.affectedRows) return null;
    const action = status === "suspended" ? "SUSPEND_USER" : "REACTIVATE_USER";
    await this.recordAction(actingProfile, "user", id, action);
    const [rows] = await this.pool.execute(
      `SELECT id, firebase_uid AS firebaseUid, name, email, role, status,
              DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s.000Z') AS createdAt,
              DATE_FORMAT(updated_at, '%Y-%m-%dT%H:%i:%s.000Z') AS updatedAt
       FROM users WHERE id = ?`,
      [id],
    );
    return mapProfile(rows[0]);
  }

  async listAdminFacilities(query) {
    const conditions = [];
    const params = [];
    if (query.active === "true") conditions.push("is_active = TRUE");
    if (query.active === "false") conditions.push("is_active = FALSE");
    const [rows] = await this.pool.execute(
      `SELECT id, name, latitude, longitude, is_active AS isActive, is_sample AS isSample,
              DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s.000Z') AS createdAt,
              DATE_FORMAT(updated_at, '%Y-%m-%dT%H:%i:%s.000Z') AS updatedAt
       FROM facilities ${conditions.length ? `WHERE ${conditions.join(" AND ")}` : ""}
       ORDER BY name`,
      params,
    );
    return rows.map((row) => ({
      ...row,
      latitude: Number(row.latitude),
      longitude: Number(row.longitude),
      isActive: Boolean(row.isActive),
      isSample: Boolean(row.isSample),
    }));
  }

  async createFacility(fields, actingProfile) {
    const id = randomUUID();
    await this.pool.execute(
      "INSERT INTO facilities (id, name, latitude, longitude, is_active, is_sample) VALUES (?, ?, ?, ?, ?, FALSE)",
      [id, fields.name, fields.latitude, fields.longitude, fields.isActive ?? true],
    );
    await this.recordAction(actingProfile, "facility", id, "CREATE_FACILITY");
    return (await this.listAdminFacilities({})).find((item) => item.id === id);
  }

  async updateFacility(id, fields, actingProfile) {
    const updates = [];
    const values = [];
    for (const field of ["name", "latitude", "longitude", "isActive"]) {
      if (fields[field] !== undefined) {
        updates.push(`${field === "isActive" ? "is_active" : field} = ?`);
        values.push(fields[field]);
      }
    }
    if (updates.length) {
      values.push(id);
      await this.pool.execute(`UPDATE facilities SET ${updates.join(", ")} WHERE id = ?`, values);
    }
    const facility = (await this.listAdminFacilities({})).find((item) => item.id === id);
    if (facility) {
      await this.recordAction(actingProfile, "facility", id, fields.isActive === false ? "DEACTIVATE_FACILITY" : "UPDATE_FACILITY");
    }
    return facility || null;
  }

  async listActions(query) {
    const where = query.targetId ? "WHERE target_id = ?" : "";
    const [rows] = await this.pool.execute(
      `SELECT id, acting_admin_id AS actingAdminId, target_type AS targetType,
              target_id AS targetId, action,
              DATE_FORMAT(created_at, '%Y-%m-%dT%H:%i:%s.000Z') AS timestamp
       FROM admin_actions ${where} ORDER BY created_at DESC`,
      query.targetId ? [query.targetId] : [],
    );
    return rows;
  }

  async recordAction(actingProfile, targetType, targetId, action) {
    await this.pool.execute(
      "INSERT INTO admin_actions (id, acting_admin_id, target_type, target_id, action) VALUES (?, ?, ?, ?, ?)",
      [randomUUID(), actingProfile.id, targetType, targetId, action],
    );
  }

  haversine(latitude, longitude, facility) {
    const toRadians = (degrees) => degrees * Math.PI / 180;
    const dLat = toRadians(Number(facility.latitude) - latitude);
    const dLon = toRadians(Number(facility.longitude) - longitude);
    const a = Math.sin(dLat / 2) ** 2 +
      Math.cos(toRadians(latitude)) * Math.cos(toRadians(Number(facility.latitude))) * Math.sin(dLon / 2) ** 2;
    return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
}

module.exports = { MysqlStore, createPoolFromEnvironment };
