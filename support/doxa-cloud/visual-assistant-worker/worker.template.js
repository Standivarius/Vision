const APP_IDENTITY = Object.freeze({
  service: "doxa-visual-assistant",
  difyAppId: "c94b6e55-3f7f-4b8f-a2d2-99fe960959a1",
  difyAppName: "Visual Assistant",
  configuredModelId: "muse-spark-1.3-contributor",
  configuredModelName: "Muse Spark 1.3 Contributor",
});

const KNOWLEDGE_BUNDLE = __VISUAL_KNOWLEDGE_BUNDLE__;

const STOP_WORDS = new Set([
  "a", "an", "and", "are", "as", "at", "be", "but", "by", "can", "do", "does", "for", "from",
  "how", "i", "if", "in", "is", "it", "me", "my", "of", "on", "or", "that", "the", "this", "to",
  "use", "using", "what", "when", "where", "which", "why", "with", "you", "your"
]);

const QUERY_ALIASES = Object.freeze({
  caret: ["text", "cursor", "insertion"],
  cursor: ["caret", "text"],
  freeze: ["hooked", "pinned", "persistent"],
  hooked: ["freeze", "pinned", "persistent"],
  x1: ["1x", "return", "normal"],
  "1x": ["x1", "return", "normal"],
  mouse: ["pointer"],
  pointer: ["mouse"],
  color: ["colour", "contrast", "invert"],
  colour: ["color", "contrast", "invert"],
  monitor: ["display", "screen"],
  display: ["monitor", "screen"],
  screen: ["monitor", "display"],
  tracking: ["follow"],
  follow: ["tracking"],
  locator: ["rectangle", "frame", "overview"],
  reference: ["fixed", "keep", "visible"],
});

function json(value, status = 200) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });
}

function normalizeContext(value) {
  const input = value && typeof value === "object" && !Array.isArray(value) ? value : {};
  const bool = (name) => input[name] === true;
  const zoom = Number(input.zoom);
  const monitorCount = Number(input.monitor_count);
  const allowedModes = new Set(["normal", "increase_contrast", "inverted_colours", "grayscale"]);
  const visualMode = allowedModes.has(String(input.visual_mode || ""))
    ? String(input.visual_mode)
    : "normal";

  return {
    zoom: Number.isFinite(zoom) && zoom >= 1 && zoom <= 8 ? zoom : 1,
    tracking_enabled: bool("tracking_enabled"),
    follow_pointer: bool("follow_pointer"),
    follow_text_cursor: bool("follow_text_cursor"),
    follow_keyboard_focus: bool("follow_keyboard_focus"),
    pointer_locator: bool("pointer_locator"),
    text_cursor_highlight: bool("text_cursor_highlight"),
    focus_highlight: bool("focus_highlight"),
    view_locator: bool("view_locator"),
    visual_mode: visualMode,
    monitor_count: Number.isFinite(monitorCount) ? Math.max(0, Math.min(16, Math.trunc(monitorCount))) : 0,
    single_monitor: bool("single_monitor"),
    context_assigned: bool("context_assigned"),
    detail_assigned: bool("detail_assigned"),
    reference_assigned: bool("reference_assigned"),
  };
}

function normalizeTokens(text) {
  const tokens = String(text || "")
    .toLowerCase()
    .replace(/[^a-z0-9+&.-]+/g, " ")
    .split(/\s+/)
    .map(x => x.trim())
    .filter(x => x.length >= 2 && !STOP_WORDS.has(x));

  const expanded = new Set(tokens);
  for (const token of tokens) {
    for (const alias of QUERY_ALIASES[token] || []) expanded.add(alias);
  }
  return [...expanded];
}

function chunkText(chunk) {
  return `${chunk.product || ""} ${chunk.title || ""} ${(chunk.keywords || []).join(" ")} ${chunk.content || ""}`.toLowerCase();
}

function evidencePriority(kind) {
  switch (kind) {
    case "visual-source": return 6;
    case "visual-doc": return 5;
    case "visual-reference": return 4;
    case "incumbent-official": return 3;
    case "project-research": return 1;
    default: return 0;
  }
}

function scoreKnowledgeChunk(chunk, question, tokens) {
  const hay = chunkText(chunk);
  const title = String(chunk.title || "").toLowerCase();
  const product = String(chunk.product || "").toLowerCase();
  let score = evidencePriority(chunk.kind) * 0.2;

  for (const token of tokens) {
    if (title.includes(token)) score += 5;
    else if ((chunk.keywords || []).some(x => String(x).toLowerCase().includes(token))) score += 4;
    else if (hay.includes(token)) score += token.length >= 6 ? 2.2 : 1.4;
  }

  const q = question.toLowerCase();
  const asksVisual = /\bvisual\b|\bcurrent\b|\bimplemented\b|\bsetting\b|\bshortcut\b|\bcode\b|\bsource\b/.test(q);
  const asksZoomText = /zoom\s*text|zoomtext|freeze view|multiview|view locator/.test(q);
  const asksSuperNova = /super\s*nova|supernova|hooked area|hooked region/.test(q);
  const asksWindows = /windows magnifier|microsoft magnifier/.test(q);

  if (asksVisual && (chunk.kind === "visual-source" || chunk.kind === "visual-doc")) score += 6;
  if (asksZoomText && product.includes("zoomtext")) score += 8;
  if (asksSuperNova && product.includes("supernova")) score += 8;
  if (asksWindows && product.includes("windows magnifier")) score += 8;

  if (/freeze|hooked/.test(q) && /freeze|hooked/.test(hay)) score += 5;
  if (/reference/.test(q) && /reference/.test(hay)) score += 4;
  if (/tracking|follow|typing|caret|cursor/.test(q) && /tracking|follow|caret|cursor/.test(hay)) score += 4;
  if (/monitor|display|screen/.test(q) && /monitor|display|screen/.test(hay)) score += 3;
  if (/1x|x1|return/.test(q) && /1x|x1|return/.test(hay)) score += 3;

  return score;
}

function retrieveKnowledge(question, context, options = {}) {
  const maxChunks = Math.max(1, Math.min(10, Number(options.maxChunks || 7)));
  const maxChars = Math.max(2000, Math.min(18000, Number(options.maxChars || 12000)));
  const tokens = normalizeTokens(question);
  const q = question.toLowerCase();
  const scored = KNOWLEDGE_BUNDLE.chunks
    .map(chunk => ({ chunk, score: scoreKnowledgeChunk(chunk, question, tokens) }))
    .filter(item => item.score > 1.0)
    .sort((a, b) => b.score - a.score || evidencePriority(b.chunk.kind) - evidencePriority(a.chunk.kind));

  const selected = [];
  const selectedIds = new Set();
  const seenSources = new Map();
  let chars = 0;

  const tryAdd = (item) => {
    if (!item || selected.length >= maxChunks || selectedIds.has(item.chunk.id)) return false;
    const sourceKey = item.chunk.source_name || item.chunk.source_url || item.chunk.id;
    const sourceCount = seenSources.get(sourceKey) || 0;
    if (sourceCount >= 3) return false;
    const content = String(item.chunk.content || "");
    if (!content) return false;
    if (selected.length > 0 && chars + content.length > maxChars) return false;
    selected.push({ ...item.chunk, score: Number(item.score.toFixed(2)) });
    selectedIds.add(item.chunk.id);
    seenSources.set(sourceKey, sourceCount + 1);
    chars += content.length;
    return true;
  };

  const requireIncumbent = (productPattern) => {
    const item = scored.find(candidate =>
      candidate.chunk.kind === "incumbent-official" &&
      productPattern.test(String(candidate.chunk.product || "").toLowerCase()));
    tryAdd(item);
  };

  if (/zoom\s*text|zoomtext|freeze view|multiview/.test(q)) requireIncumbent(/zoomtext/);
  if (/super\s*nova|supernova|hooked area|hooked region/.test(q)) requireIncumbent(/supernova/);
  if (/windows magnifier|microsoft magnifier/.test(q)) requireIncumbent(/windows magnifier/);

  const asksMigration = /zoom\s*text|zoomtext|super\s*nova|supernova|freeze|hooked|windows magnifier/.test(q);
  if (asksMigration) {
    // Migration answers need current Visual truth alongside incumbent behavior.
    tryAdd(scored.find(item => item.chunk.kind === "visual-source" || item.chunk.kind === "visual-doc"));
  }

  for (const item of scored) {
    if (selected.length >= maxChunks) break;
    tryAdd(item);
  }

  return selected;
}
function formatKnowledgeEvidence(chunks) {
  if (!chunks.length) return "No matching reference evidence was retrieved.";
  return chunks.map((chunk, index) => {
    const authority = chunk.kind === "visual-source" || chunk.kind === "visual-doc"
      ? "CURRENT VISUAL EVIDENCE"
      : chunk.kind === "incumbent-official"
        ? "OFFICIAL INCUMBENT EVIDENCE"
        : "PROJECT RESEARCH / INTERPRETATION";
    return `[${index + 1}] ${authority}\nTitle: ${chunk.title}\nSource: ${chunk.source_name || chunk.source_url}\nReference: ${chunk.source_url}\nContent:\n${chunk.content}`;
  }).join("\n\n");
}

function buildQuery(question, context, knowledge) {
  return `User question:\n${question}\n\nCurrent Visual state (structured application state; not screen content):\n${JSON.stringify(context)}\n\nRetrieved reference evidence:\n${formatKnowledgeEvidence(knowledge)}\n\nEvidence rules:\n- For claims about what Visual currently implements, CURRENT VISUAL EVIDENCE is authoritative.\n- OFFICIAL INCUMBENT EVIDENCE describes ZoomText, SuperNova or Windows Magnifier only; never turn an incumbent feature into a Visual feature unless current Visual evidence confirms it.\n- PROJECT RESEARCH / INTERPRETATION is lower authority than current Visual source/docs and official incumbent documentation.\n- If the evidence does not support an answer, say what is not known instead of inventing behavior.\n- Do not expose internal source IDs or repository paths unless the user explicitly asks for implementation detail.\n\nAnswer the user's question using the Visual Assistant instructions and the evidence above. Keep the answer concise and actionable.`;
}

async function callDify(env, question, context, knowledge) {
  if (!env.DIFY_API_KEY) throw new Error("assistant_not_configured");

  const response = await fetch("https://api.dify.ai/v1/chat-messages", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.DIFY_API_KEY}`,
      "content-type": "application/json",
      accept: "application/json",
    },
    body: JSON.stringify({
      inputs: {},
      query: buildQuery(question, context, knowledge),
      response_mode: "blocking",
      conversation_id: "",
      user: "visual-desktop",
    }),
  });

  if (!response.ok) throw new Error(`assistant_upstream_${response.status}`);
  const payload = await response.json();
  if (!payload || typeof payload.answer !== "string" || !payload.answer.trim()) {
    throw new Error("assistant_invalid_response");
  }

  return {
    answer: payload.answer.trim().slice(0, 12000),
    taskId: typeof payload.task_id === "string" ? payload.task_id : "",
    messageId: typeof payload.message_id === "string"
      ? payload.message_id
      : (typeof payload.id === "string" ? payload.id : ""),
  };
}

function authorizedPath(url, env) {
  if (!env.VISUAL_ROUTE_TOKEN) return false;
  const expected = `/v1/ask/${env.VISUAL_ROUTE_TOKEN}`;
  return url.pathname === expected;
}

export { normalizeContext, retrieveKnowledge, buildQuery };

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return json({
        ok: true,
        service: APP_IDENTITY.service,
        schema_version: "1",
        provider: "dify",
        dify_app_id: APP_IDENTITY.difyAppId,
        dify_app_name: APP_IDENTITY.difyAppName,
        configured_model_id: APP_IDENTITY.configuredModelId,
        configured_model_name: APP_IDENTITY.configuredModelName,
        model_identity_source: "worker_config",
        retrieval_version: "2-diverse-evidence",
        knowledge: {
          schema_version: KNOWLEDGE_BUNDLE.schema_version,
          chunk_count: KNOWLEDGE_BUNDLE.chunk_count,
          source_tree_sha256: KNOWLEDGE_BUNDLE.source_tree_sha256,
        },
      });
    }

    if (request.method !== "POST" || !authorizedPath(url, env)) {
      return json({ error: "not_found" }, 404);
    }

    const contentLength = Number(request.headers.get("content-length") || 0);
    if (contentLength > 32768) return json({ error: "request_too_large" }, 413);

    let input;
    try {
      input = await request.json();
    } catch {
      return json({ error: "invalid_json" }, 400);
    }

    if (!input || input.schema_version !== "1" || input.intent !== "ask_visual") {
      return json({ error: "invalid_request" }, 400);
    }

    const question = typeof input.question === "string" ? input.question.trim() : "";
    if (!question || question.length > 2000) {
      return json({ error: "invalid_question" }, 400);
    }

    const context = normalizeContext(input.context);
    const knowledge = retrieveKnowledge(question, context);

    try {
      const result = await callDify(env, question, context, knowledge);
      return json({
        schema_version: "1",
        title: "Ask Visual",
        answer: result.answer,
        provider: "dify",
        dify_app_id: APP_IDENTITY.difyAppId,
        configured_model_id: APP_IDENTITY.configuredModelId,
        configured_model_name: APP_IDENTITY.configuredModelName,
        knowledge: {
          source_tree_sha256: KNOWLEDGE_BUNDLE.source_tree_sha256,
          chunk_ids: knowledge.map(chunk => chunk.id),
        },
        trace: {
          task_id: result.taskId,
          message_id: result.messageId,
        },
      });
    } catch (error) {
      const code = String(error?.message || "assistant_failed");
      return json({ error: "assistant_failed", code }, 502);
    }
  },
};