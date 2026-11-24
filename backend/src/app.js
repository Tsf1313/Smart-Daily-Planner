const express = require("express");
<<<<<<< HEAD
const multer = require("multer");
const { MemoryStore } = require("./store/memory");
const { createFirebaseVerifier } = require("./auth");
const { validateEntry, validateFacilitySearch, validatePaging } = require("./validation");

function errorResponse(response, status, code, message, details) {
  const body = { error: { code, message } };
  if (details) body.error.details = details;
  return response.status(status).json(body);
}

function createApp(options = {}) {
  const app = express();
  const store = options.store || new MemoryStore();
  const verifyFirebaseToken =
    options.verifyFirebaseToken || createFirebaseVerifier();

  app.disable("x-powered-by");
  app.use(express.json({ limit: "1mb" }));

  app.get("/health", (_request, response) => {
    response.status(200).json({ status: "ok" });
  });

  app.use("/api/v1", async (request, response, next) => {
    if (request.method === "OPTIONS") return next();
    const authorization = request.headers.authorization || "";
    if (!authorization.startsWith("Bearer ")) {
      return errorResponse(response, 401, "UNAUTHENTICATED", "Missing authentication token.");
    }
    try {
      const claims = await verifyFirebaseToken(authorization.slice(7));
      const profile = await store.getOrCreateProfile(claims);
      if (profile.status === "suspended") {
        return errorResponse(response, 403, "ACCOUNT_SUSPENDED", "This account is suspended.");
      }
      request.profile = profile;
      next();
    } catch (_error) {
      return errorResponse(response, 401, "UNAUTHENTICATED", "Invalid or expired authentication token.");
    }
  });

  app.get("/api/v1/me", async (request, response) => {
    response.json({ data: request.profile });
  });

  app.patch("/api/v1/me", async (request, response) => {
    const name = request.body.name;
    if (typeof name !== "string" || !name.trim() || name.trim().length > 100) {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", {
        name: "Name must contain 1 to 100 characters.",
      });
    }
    const profile = await store.updateProfile(request.profile.id, { name: name.trim() });
    response.json({ data: profile });
  });

  app.post("/api/v1/entries", async (request, response) => {
    const validation = validateEntry(request.body, "create");
    if (!validation.valid) {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", validation.details);
    }
    const entry = await store.createEntry(request.profile.id, validation.value);
    response.status(201).json({ data: entry });
  });

  app.get("/api/v1/entries", async (request, response) => {
    const range = validateRange(request.query);
    if (!range.valid) {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", range.details);
    }
    const paging = validatePaging(request.query);
    if (!paging.valid) {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", paging.details);
    }
    const result = await store.listEntries(request.profile.id, range.value, paging.value);
    response.json({ data: result });
  });

  app.get("/api/v1/entries/:id", async (request, response) => {
    const entry = await store.getEntry(request.profile.id, request.params.id);
    if (!entry) return errorResponse(response, 404, "NOT_FOUND", "Entry not found.");
    response.json({ data: entry });
  });

  app.patch("/api/v1/entries/:id", async (request, response) => {
    const validation = validateEntry(request.body, "patch");
    if (!validation.valid) {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", validation.details);
    }
    const existing = await store.getEntry(request.profile.id, request.params.id);
    if (!existing) return errorResponse(response, 404, "NOT_FOUND", "Entry not found.");
    if (validation.value.kind && validation.value.kind !== existing.kind) {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", {
        kind: "Kind cannot change after creation.",
      });
    }
    const entry = await store.updateEntry(request.profile.id, request.params.id, validation.value);
    response.json({ data: entry });
  });

  app.delete("/api/v1/entries/:id", async (request, response) => {
    const deleted = await store.deleteEntry(request.profile.id, request.params.id);
    if (!deleted) return errorResponse(response, 404, "NOT_FOUND", "Entry not found.");
    response.json({ data: { id: request.params.id, deleted: true } });
  });

  app.put("/api/v1/entries/:id/completion", async (request, response) => {
    if (typeof request.body.isCompleted !== "boolean") {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", {
        isCompleted: "isCompleted must be true or false.",
      });
    }
    const entry = await store.setDeadlineCompletion(request.profile.id, request.params.id, request.body.isCompleted);
    if (!entry) return errorResponse(response, 404, "NOT_FOUND", "Deadline not found.");
    response.json({ data: entry });
  });

  app.get("/api/v1/routine-occurrences", async (request, response) => {
    const range = validateRange(request.query);
    if (!range.valid) {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", range.details);
    }
    const occurrences = await store.listOccurrences(request.profile.id, range.value);
    response.json({ data: { items: occurrences } });
  });

  app.put("/api/v1/routine-occurrences/:id/completion", async (request, response) => {
    if (typeof request.body.isCompleted !== "boolean") {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", {
        isCompleted: "isCompleted must be true or false.",
      });
    }
    const occurrence = await store.setOccurrenceCompletion(request.profile.id, request.params.id, request.body.isCompleted);
    if (!occurrence) return errorResponse(response, 404, "NOT_FOUND", "Occurrence not found.");
    response.json({ data: occurrence });
  });

  app.get("/api/v1/facilities", async (request, response) => {
    const validation = validateFacilitySearch(request.query);
    if (!validation.valid) {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", validation.details);
    }
    const facilities = await store.listFacilities(validation.value);
    response.json({ data: { items: facilities } });
  });

  const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024, files: 1 },
  });

  app.post("/api/v1/photos", upload.single("file"), async (request, response) => {
    if (!request.file) {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", { file: "File is required." });
    }
    const allowed = { "image/jpeg": true, "image/png": true };
    if (!allowed[request.file.mimetype]) {
      return errorResponse(response, 415, "UNSUPPORTED_MEDIA_TYPE", "Only JPEG and PNG photos are supported.");
    }
    const bytes = request.file.buffer;
    const jpeg = bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
    const png =
      bytes.length >= 8 &&
      bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47 &&
      bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a;
    if (!jpeg && !png) {
      return errorResponse(response, 415, "UNSUPPORTED_MEDIA_TYPE", "The uploaded content is not a valid JPEG or PNG.");
    }
    const photo = await store.createPhoto(request.profile.id, request.file);
    response.status(201).json({ data: photo });
  });

  app.get("/api/v1/photos/:id", async (request, response) => {
    const photo = await store.getPhoto(request.profile.id, request.params.id);
    if (!photo) return errorResponse(response, 404, "NOT_FOUND", "Photo not found.");
    response.type(photo.mimeType).send(photo.data);
  });

  app.delete("/api/v1/photos/:id", async (request, response) => {
    const deleted = await store.deletePhoto(request.profile.id, request.params.id);
    if (!deleted) return errorResponse(response, 404, "NOT_FOUND", "Photo not found.");
    response.json({ data: { id: request.params.id, deleted: true } });
  });

  app.use("/api/v1/admin", async (request, response, next) => {
    if (request.profile.role !== "super_admin") {
      return errorResponse(response, 403, "FORBIDDEN", "Super Admin permission required.");
    }
    next();
  });

  app.get("/api/v1/admin/users", async (request, response) => {
    const result = await store.listUsers(request.query, request.profile);
    response.json({ data: result });
  });

  app.patch("/api/v1/admin/users/:id/status", async (request, response) => {
    const status = request.body.status;
    if (!["active", "suspended"].includes(status)) {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", {
        status: "Status must be active or suspended.",
      });
    }
    if (request.params.id === request.profile.id) {
      return errorResponse(response, 403, "FORBIDDEN", "An admin cannot suspend or reactivate their own account.");
    }
    const result = await store.setUserStatus(request.params.id, status, request.profile);
    if (!result) return errorResponse(response, 404, "NOT_FOUND", "Account not found.");
    response.json({ data: result });
  });

  app.get("/api/v1/admin/facilities", async (request, response) => {
    response.json({ data: { items: await store.listAdminFacilities(request.query) } });
  });

  app.post("/api/v1/admin/facilities", async (request, response) => {
    const validation = validateFacility(request.body);
    if (!validation.valid) {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", validation.details);
    }
    const facility = await store.createFacility(validation.value, request.profile);
    response.status(201).json({ data: facility });
  });

  app.patch("/api/v1/admin/facilities/:id", async (request, response) => {
    const validation = validateFacility(request.body, true);
    if (!validation.valid) {
      return errorResponse(response, 400, "VALIDATION_ERROR", "Please check the submitted fields.", validation.details);
    }
    const facility = await store.updateFacility(request.params.id, validation.value, request.profile);
    if (!facility) return errorResponse(response, 404, "NOT_FOUND", "Facility not found.");
    response.json({ data: facility });
  });

  app.get("/api/v1/admin/actions", async (request, response) => {
    response.json({ data: { items: await store.listActions(request.query) } });
  });

  app.use((error, _request, response, _next) => {
    if (error instanceof multer.MulterError && error.code === "LIMIT_FILE_SIZE") {
      return errorResponse(response, 413, "UPLOAD_TOO_LARGE", "Photo must not exceed 5 MB.");
    }
    console.error(error);
    return errorResponse(response, 500, "INTERNAL_ERROR", "An unexpected server error occurred.");
  });

  return app;
}

function validateRange(query) {
  if (!query.from || !query.to) {
    return { valid: false, details: { from: "from is required.", to: "to is required." } };
  }
  const from = new Date(query.from);
  const to = new Date(query.to);
  if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime())) {
    return { valid: false, details: { range: "from and to must be ISO 8601 timestamps." } };
  }
  if (to <= from || to - from > 31 * 24 * 60 * 60 * 1000) {
    return { valid: false, details: { range: "Range must be positive and no longer than 31 days." } };
  }
  return { valid: true, value: { from: from.toISOString(), to: to.toISOString() } };
}

function validateFacility(body, patch = false) {
  const details = {};
  const value = {};
  for (const field of ["name", "latitude", "longitude", "isActive"]) {
    if (body[field] !== undefined) value[field] = body[field];
  }
  if (!patch || body.name !== undefined) {
    if (typeof value.name !== "string" || !value.name.trim() || value.name.trim().length > 150) {
      details.name = "Name must contain 1 to 150 characters.";
    } else value.name = value.name.trim();
  }
  if (!patch || body.latitude !== undefined) {
    if (typeof value.latitude !== "number" || value.latitude < -90 || value.latitude > 90) {
      details.latitude = "Latitude must be between -90 and 90.";
    }
  }
  if (!patch || body.longitude !== undefined) {
    if (typeof value.longitude !== "number" || value.longitude < -180 || value.longitude > 180) {
      details.longitude = "Longitude must be between -180 and 180.";
    }
  }
  if (body.isActive !== undefined && typeof body.isActive !== "boolean") {
    details.isActive = "isActive must be true or false.";
  }
  return Object.keys(details).length ? { valid: false, details } : { valid: true, value };
}

const defaultApp = createApp();
module.exports = defaultApp;
=======
const { mountDeadlines, fail } = require("./deadlines");
const services = require("./services");

function createApp(dependencies = services) {
  const app = express();
  app.disable("x-powered-by");
  app.use(express.json());
  app.get("/health", (_req, res) => res.json({ status: "ok" }));
  mountDeadlines(app, dependencies);
  app.use((error, _req, res, _next) => {
    if (error.type === "entity.parse.failed") return fail(res, 400, "INVALID_JSON", "Invalid JSON body.");
    if (error.type === "entity.too.large") return fail(res, 413, "BODY_TOO_LARGE", "Request body too large.");
    console.error("Planner request failed", error.code || error.name);
    return fail(res, 500, "INTERNAL_ERROR", "Unable to complete the request.");
  });
  return app;
}

module.exports = createApp();
>>>>>>> 81dc15830990c3536e7160733ff99fbc99efbdae
module.exports.createApp = createApp;
