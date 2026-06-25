import { pipeline, env } from 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.3.3';

// Force Transformers.js to use native Cache Storage API and CDN resources
env.useBrowserCache = true;
env.allowLocalModels = false;
env.backends.onnx.wasm.wasmPaths = 'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.3.3/dist/';

let generator = null;

// Common English and Tagalog stop words to exclude from keyword extraction
const stopWords = new Set([
  'the', 'a', 'an', 'and', 'or', 'but', 'if', 'then', 'else', 'to', 'of', 'in', 'on', 'at', 'by', 'for', 'with', 'about', 'against', 'between', 'into', 'through', 'during', 'before', 'after', 'above', 'below', 'from', 'up', 'down', 'is', 'am', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'having', 'do', 'does', 'did', 'doing', 'i', 'you', 'he', 'she', 'it', 'we', 'they', 'them', 'their', 'this', 'that', 'these', 'those', 'will', 'would', 'shall', 'should', 'can', 'could', 'may', 'might', 'must',
  'ang', 'mga', 'ng', 'sa', 'at', 'o', 'ngunit', 'kundi', 'para', 'kay', 'kina', 'ni', 'nila', 'mo', 'nito', 'iyon', 'ito', 'doon', 'dito', 'na', 'isang', 'may', 'si', 'se', 'ya', 'ba', 'po', 'opo', 'dahil', 'kasi', 'lang', 'din', 'rin', 'naman', 'nga', 'pala', 'mismo', 'mula', 'hanggang', 'ako', 'ikaw', 'siya', 'kami', 'tayo', 'kayo', 'sila'
]);

/**
 * Initializes the local Qwen model using WebGPU.
 * @param {Function} onProgress Progress callback to track download percentage
 */
export async function initAIEngine(onProgress) {
  if (generator) return generator;

  console.log('[MulatAI Engine] Initializing WebGPU pipeline with Qwen-2.5-0.5B-Instruct...');
  try {
    generator = await pipeline('text-generation', 'onnx-community/Qwen2.5-0.5B-Instruct', {
      device: 'webgpu',
      dtype: 'q4', // 4-bit quantization for fast load/execution
      progress_callback: onProgress
    });
    console.log('[MulatAI Engine] WebGPU model loaded successfully!');
    return generator;
  } catch (error) {
    console.error('[MulatAI Engine] Failed to load model via WebGPU:', error);
    throw error;
  }
}

/**
 * Splits document text into paragraphs or semantic chunks.
 */
function getChunks(text, maxChunkSize = 800) {
  const paragraphs = text.split(/\n\s*\n/);
  const chunks = [];
  let currentChunk = '';
  
  for (let p of paragraphs) {
    p = p.trim();
    if (!p) continue;
    if ((currentChunk + '\n\n' + p).length <= maxChunkSize) {
      currentChunk = currentChunk ? currentChunk + '\n\n' + p : p;
    } else {
      if (currentChunk) chunks.push(currentChunk);
      if (p.length > maxChunkSize) {
        // Fallback: split long paragraph by sentences
        const sentences = p.split(/[.!?]\s+/);
        currentChunk = '';
        for (let s of sentences) {
          if ((currentChunk + ' ' + s).length <= maxChunkSize) {
            currentChunk = currentChunk ? currentChunk + ' ' + s : s;
          } else {
            if (currentChunk) chunks.push(currentChunk);
            currentChunk = s;
          }
        }
      } else {
        currentChunk = p;
      }
    }
  }
  if (currentChunk) chunks.push(currentChunk);
  return chunks;
}

/**
 * Extracts key terms by analyzing word frequencies (TF-IDF equivalent).
 */
function extractKeywords(text, count = 5) {
  const words = text.toLowerCase().match(/[a-z\u00C0-\u024F]+/g) || [];
  const freqs = {};
  for (const w of words) {
    if (w.length < 4 || stopWords.has(w)) continue;
    freqs[w] = (freqs[w] || 0) + 1;
  }
  return Object.entries(freqs)
    .sort((a, b) => b[1] - a[1])
    .slice(0, count)
    .map(entry => entry[0]);
}

/**
 * Scores and retrieves chunks matching the query terms.
 */
function retrieveChunks(chunks, query, count = 1) {
  const queryTerms = query.toLowerCase().split(/\s+/);
  const scored = chunks.map(chunk => {
    let score = 0;
    const chunkLower = chunk.toLowerCase();
    for (const term of queryTerms) {
      if (term.length < 3) continue;
      
      // Match whole words to boost relevance
      const regex = new RegExp('\\b' + term + '\\b', 'g');
      const matches = chunkLower.match(regex);
      if (matches) {
        score += matches.length * 2;
      }
      
      // Also check simple inclusion
      if (chunkLower.includes(term)) {
        score += 1;
      }
    }
    return { chunk, score };
  });
  
  return scored
    .filter(item => item.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, count)
    .map(item => item.chunk);
}

/**
 * Generates study materials based on the provided text, type, and language.
 * Uses a dynamic RAG pipeline to chunk and retrieve relevant text blocks to optimize context window tokens.
 * @param {string} contextText The source material text
 * @param {string} type 'reviewer', 'flashcards', or 'quiz'
 * @param {string} language 'english', 'filipino', or 'taglish'
 */
export async function generateStudyMaterial(contextText, type, language = 'taglish') {
  if (!generator) {
    throw new Error('AI Engine is not initialized. Please call initAIEngine first.');
  }

  // --- RAG PIPELINE START ---
  let retrievedContext = contextText.trim();
  if (contextText.length > 2500) {
    console.log(`[MulatAI RAG] Document length (${contextText.length} chars) exceeds optimal context. Activating RAG...`);
    
    // 1. Chunking
    const chunks = getChunks(contextText, 800);
    console.log(`[MulatAI RAG] Generated ${chunks.length} document chunks.`);
    
    // 2. Keyword/Concept Extraction
    const keywords = extractKeywords(contextText, 6);
    console.log(`[MulatAI RAG] Identified key document concepts:`, keywords);
    
    // 3. Retrieval
    const selectedChunks = new Set();
    for (const keyword of keywords) {
      const bestChunks = retrieveChunks(chunks, keyword, 1);
      if (bestChunks.length > 0) {
        selectedChunks.add(bestChunks[0]);
      }
    }
    
    // Fallback if no keywords found/retrieved
    if (selectedChunks.size === 0) {
      chunks.slice(0, 3).forEach(c => selectedChunks.add(c));
    }
    
    // Compile retrieved sections into a single RAG context
    retrievedContext = Array.from(selectedChunks).join('\n\n---\n\n');
    console.log(`[MulatAI RAG] Retrieved context compacted to ${retrievedContext.length} characters (Saved ~${Math.round((contextText.length - retrievedContext.length) / 4)} tokens).`);
  }
  // --- RAG PIPELINE END ---

  // Standardize language name
  let targetLanguage = 'Taglish';
  if (language.toLowerCase() === 'filipino') targetLanguage = 'Filipino';
  if (language.toLowerCase() === 'english') targetLanguage = 'English';

  // Construct structured prompt forcing JSON output and enforcing RAG rules
  const systemPrompt = `You are MulatAI, an offline study assistant. You must generate study materials based ONLY on the provided Context.
Do not introduce external facts or hallucinate details. Use the user's selected language: ${targetLanguage}.

Language Rules:
- English: Standard academic English.
- Filipino: Formal/standard Filipino, using local analogies when appropriate.
- Taglish: Colloquial Tagalog-English mix, keeping core academic/technical terms in English but explanations in familiar conversational Filipino with local analogies.

Output Rules:
- Output MUST be a valid JSON object. Do not include markdown formatting (like \`\`\`json) or conversational preambles outside the raw JSON.
- Strictly adhere to the requested schema.

Depending on the requested type, generate the following JSON schema:

1. If type is 'reviewer':
Return a JSON object containing a detailed study guide in markdown:
{
  "reviewer": "markdown formatting containing headers, bullet points, and clean explanations of concepts in the text"
}

2. If type is 'flashcards':
Return a JSON object containing an array of exactly 5 flashcards:
{
  "flashcards": [
    {
      "concept": "term or concept name",
      "definition": "definition of the term, including local analogies if using Taglish/Filipino"
    }
  ]
}

3. If type is 'quiz':
Return a JSON object containing exactly 5 multiple-choice questions:
{
  "quiz": [
    {
      "question": "question text",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_index": 0,
      "explanation": "explanation of why this option is correct"
    }
  ]
}`;

  const messages = [
    { role: 'system', content: systemPrompt },
    { role: 'user', content: `Context:\n${retrievedContext}\n\nGenerate type: ${type}` }
  ];

  console.log(`[MulatAI Engine] Generating '${type}' study material in ${targetLanguage} using retrieved context...`);
  
  const response = await generator(messages, {
    max_new_tokens: 1024,
    temperature: 0.1, // low temperature for structured formats
    top_k: 20
  });

  let rawResult = '';
  if (Array.isArray(response) && response[0]) {
    if (Array.isArray(response[0].generated_text)) {
      rawResult = response[0].generated_text.slice(-1)[0].content;
    } else if (typeof response[0].generated_text === 'string') {
      rawResult = response[0].generated_text;
    }
  }

  // Handle case where system prefix is returned along with user content
  if (!rawResult && response[0] && response[0].content) {
    rawResult = response[0].content;
  }

  console.log('[MulatAI Engine] Raw model output:', rawResult);

  // Clean up and parse the JSON block
  return extractAndParseJSON(rawResult);
}

/**
 * Robustly extracts and parses JSON from the model's text response.
 * @param {string} text 
 */
function extractAndParseJSON(text) {
  // Try cleaning typical markdown code fences if present
  let cleaned = text.trim();
  if (cleaned.startsWith('```')) {
    cleaned = cleaned.replace(/^```(json)?/, '').replace(/```$/, '').trim();
  }

  const startIndex = cleaned.indexOf('{');
  const endIndex = cleaned.lastIndexOf('}');

  if (startIndex === -1 || endIndex === -1 || endIndex < startIndex) {
    throw new Error('No valid JSON block detected in model output.');
  }

  const jsonString = cleaned.substring(startIndex, endIndex + 1).trim();
  try {
    return JSON.parse(jsonString);
  } catch (err) {
    console.warn('[MulatAI Engine] Standard JSON parse failed, trying lenient cleanup:', err);
    
    // Attempt minor fixes for trailing commas or common small issues
    try {
      const lenientString = jsonString
        .replace(/,\s*([\]}])/g, '$1') // remove trailing commas
        .replace(/[\u0000-\u0019]+/g, ''); // remove control chars
      return JSON.parse(lenientString);
    } catch (secondErr) {
      throw new Error(`Failed to parse LLM JSON: ${secondErr.message}. Output was: ${jsonString}`);
    }
  }
}
