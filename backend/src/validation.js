function isString(value) {
  return typeof value === "string";
}

function validDateOnly(value) {
  if (!isString(value) || !/^[1-9]\d{3}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function validateLocation(location) {
  if (location === undefined || location === null) return { valid: true, value: null };
  if (typeof location !== "object" || Array.isArray(location)) {
    return { valid: false, details: { location: "Location must be an object or null." } };
  }
  const details = {};
  if (location.facilityId !== undefined && location.facilityId !== null && !isString(location.facilityId)) {
    details.facilityId = "facilityId must be a string or null.";
  }
  if (!isString(location.name) || !location.name.trim() || location.name.trim().length > 150) {
    details.name = "Location name must contain 1 to 150 characters.";
  }
  if (typeof location.latitude !== "number" || location.latitude < -90 || location.latitude > 90) {
    details.latitude = "Latitude must be between -90 and 90.";
  }
  if (typeof location.longitude !== "number" || location.longitude < -180 || location.longitude > 180) {
    details.longitude = "Longitude must be between -180 and 180.";
  }
  if (Object.keys(details).length) return { valid: false, details: { location: details } };
  return {
    valid: true,
    value: {
      facilityId: location.facilityId ?? null,
      name: location.name.trim(),
      latitude: location.latitude,
      longitude: location.longitude,
    },
  };
}

function validateEntry(body, mode) {
  const details = {};
  const value = {};
  if (mode === "create") {
    if (!["deadline", "routine"].includes(body.kind)) details.kind = "Kind must be deadline or routine.";
  } else if (body.kind !== undefined) value.kind = body.kind;

  if (body.title !== undefined) {
    if (!isString(body.title) || !body.title.trim() || body.title.trim().length > 100) {
      details.title = "Title must contain 1 to 100 characters.";
    } else value.title = body.title.trim();
  } else if (mode === "create") details.title = "Title is required.";

  if (body.description !== undefined) {
    if (body.description !== null && (!isString(body.description) || body.description.length > 2000)) {
      details.description = "Description must be null or contain no more than 2,000 characters.";
    } else value.description = body.description;
  }

  if (body.timeZone !== undefined) {
    if (body.timeZone !== "Asia/Kuala_Lumpur") details.timeZone = "timeZone must be Asia/Kuala_Lumpur.";
    else value.timeZone = body.timeZone;
  } else if (mode === "create") value.timeZone = "Asia/Kuala_Lumpur";

  if (body.reminderMinutes !== undefined) {
    if (body.reminderMinutes !== null && ![15, 30].includes(body.reminderMinutes)) {
      details.reminderMinutes = "reminderMinutes must be 15, 30, or null.";
    } else value.reminderMinutes = body.reminderMinutes;
  }

  if (body.location !== undefined) {
    const location = validateLocation(body.location);
    if (!location.valid) details.location = location.details.location;
    else value.location = location.value;
  }

  if (body.photoId !== undefined) {
    if (body.photoId !== null && !isString(body.photoId)) details.photoId = "photoId must be a string or null.";
    else value.photoId = body.photoId;
  }

  if (body.kind === "deadline" || (mode === "patch" && (body.dueAt !== undefined || body.dueDate !== undefined))) {
    if (body.dueDate !== undefined) {
      if (body.dueAt !== undefined) details.dueDate = "Provide dueDate or dueAt, not both.";
      else if (!validDateOnly(body.dueDate)) details.dueDate = "dueDate must use a valid YYYY-MM-DD date.";
      else {
        value.dueDate = body.dueDate;
        value.dueAt = `${body.dueDate}T00:00:00.000Z`;
      }
    } else if (body.dueAt !== undefined) {
      const due = new Date(body.dueAt);
      if (typeof body.dueAt !== "string" || Number.isNaN(due.getTime())) details.dueAt = "dueAt must be an ISO 8601 timestamp.";
      else value.dueAt = due.toISOString();
    } else if (mode === "create") details.dueAt = "dueAt is required.";
  }

  if (body.kind === "routine" || (mode === "patch" && body.startDate !== undefined)) {
    const routineFields = ["startDate", "startTime", "endTime", "repeat", "weekdays", "repeatUntil"];
    if (mode === "create") {
      for (const field of ["startDate", "startTime", "endTime", "repeat", "weekdays"]) {
        if (body[field] === undefined) details[field] = `${field} is required.`;
      }
    }
    for (const field of routineFields) if (body[field] !== undefined) value[field] = body[field];

    if (body.startDate !== undefined && !/^\d{4}-\d{2}-\d{2}$/.test(body.startDate)) {
      details.startDate = "startDate must use YYYY-MM-DD.";
    }
    if (body.repeatUntil !== undefined && body.repeatUntil !== null && !/^\d{4}-\d{2}-\d{2}$/.test(body.repeatUntil)) {
      details.repeatUntil = "repeatUntil must use YYYY-MM-DD or null.";
    }
    if (body.startTime !== undefined && !/^([01]\d|2[0-3]):[0-5]\d$/.test(body.startTime)) details.startTime = "startTime must use HH:mm.";
    if (body.endTime !== undefined && !/^([01]\d|2[0-3]):[0-5]\d$/.test(body.endTime)) details.endTime = "endTime must use HH:mm.";
    if (body.startTime && body.endTime && body.endTime <= body.startTime) details.endTime = "endTime must be later than startTime.";
    if (body.repeat !== undefined && !["none", "daily", "weekly"].includes(body.repeat)) details.repeat = "repeat must be none, daily, or weekly.";
    if (body.weekdays !== undefined) {
      if (!Array.isArray(body.weekdays) || body.weekdays.some((day) => !Number.isInteger(day) || day < 1 || day > 7) || new Set(body.weekdays).size !== body.weekdays.length) {
        details.weekdays = "weekdays must contain unique integers from 1 through 7.";
      }
    }
    if (body.repeat === "weekly" && (!Array.isArray(body.weekdays) || body.weekdays.length === 0)) details.weekdays = "Weekly routines require at least one weekday.";
    if (["none", "daily"].includes(body.repeat) && Array.isArray(body.weekdays) && body.weekdays.length !== 0) details.weekdays = "weekday values must be empty for none and daily.";
    if (body.repeat === "none" && body.repeatUntil !== undefined && body.repeatUntil !== null) details.repeatUntil = "repeatUntil must be null for none.";
    if (body.startDate && body.repeatUntil && body.repeatUntil < body.startDate) details.repeatUntil = "repeatUntil cannot precede startDate.";
  }

  if (Object.keys(details).length) return { valid: false, details };
  if (mode === "create") value.kind = body.kind;
  return { valid: true, value };
}

function validatePaging(query) {
  const page = query.page === undefined ? 1 : Number(query.page);
  const pageSize = query.pageSize === undefined ? 20 : Number(query.pageSize);
  if (!Number.isInteger(page) || page < 1 || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 100) {
    return { valid: false, details: { page: "page must be positive.", pageSize: "pageSize must be from 1 to 100." } };
  }
  return { valid: true, value: { page, pageSize } };
}

function validateFacilitySearch(query) {
  const latitude = Number(query.latitude);
  const longitude = Number(query.longitude);
  const radiusMeters = query.radiusMeters === undefined ? 5000 : Number(query.radiusMeters);
  const details = {};
  if (!query.latitude || !Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    details.latitude = "latitude must be a number from -90 to 90.";
  }
  if (!query.longitude || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    details.longitude = "longitude must be a number from -180 to 180.";
  }
  if (!Number.isFinite(radiusMeters) || radiusMeters < 1 || radiusMeters > 50000) {
    details.radiusMeters = "radiusMeters must be from 1 to 50000.";
  }
  if (Object.keys(details).length) return { valid: false, details };
  return { valid: true, value: { latitude, longitude, radiusMeters } };
}

module.exports = { validateEntry, validateLocation, validateFacilitySearch, validatePaging, validDateOnly };
