import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent";

interface RequestBody {
  raw_text: string;
}

interface StockItem {
  name_raw: string;
  qty: number;
  unit_label?: string;
  expiry_date?: string; // YYYY-MM-DD
  batch_no?: string;
  buy_price_bdt?: number;
  notes?: string;
  confidence?: number;
}

interface Response {
  items: StockItem[];
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiApiKey) {
      throw new Error("GEMINI_API_KEY not configured");
    }

    const { raw_text }: RequestBody = await req.json();
    if (!raw_text) {
      throw new Error("raw_text is required");
    }

    const prompt = `You are parsing a pharmacy purchase list or stock entry text. Extract medicine items with quantities, units, expiry dates, batch numbers, and prices. Return ONLY valid JSON matching this schema:
{
  "items": [
    {
      "name_raw": "Medicine name as written",
      "qty": 10,
      "unit_label": "pill|leaflet|box|bottle|vial|tube|sachet|piece|ml",
      "expiry_date": "YYYY-MM-DD or null",
      "batch_no": "Batch number or null",
      "buy_price_bdt": 50.00 or null,
      "notes": "Any additional notes",
      "confidence": 0.95
    }
  ]
}
Rules:
- Extract all medicine items from the text
- Parse quantities and units (pill, box, bottle, etc.)
- Extract expiry dates in YYYY-MM-DD format
- Extract batch numbers if mentioned
- Extract prices in BDT (Bangladesh Taka) if mentioned
- Set confidence 0.0-1.0 based on parsing certainty
- Return empty array if no items found
Return ONLY the JSON object, no markdown.`;

    const geminiUrl = `${GEMINI_API_URL}?key=${geminiApiKey}`;
    
    const response = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt + "\n\nText to parse:\n" + raw_text }] }],
        generationConfig: {
          response_mime_type: "application/json",
          response_schema: {
            type: "object",
            properties: {
              items: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    name_raw: { type: "string" },
                    qty: { type: "number" },
                    unit_label: { type: "string" },
                    expiry_date: { type: "string" },
                    batch_no: { type: "string" },
                    buy_price_bdt: { type: "number" },
                    notes: { type: "string" },
                    confidence: { type: "number" },
                  },
                  required: ["name_raw", "qty"],
                },
              },
            },
            required: ["items"],
          },
        },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Gemini API error: ${response.status} - ${errorText}`);
    }

    const geminiData = await response.json();
    let stockData: Response;
    
    if (geminiData.candidates?.[0]?.content?.parts?.[0]?.text) {
      const text = geminiData.candidates[0].content.parts[0].text;
      const cleanText = text.replace(/```json/g, "").replace(/```/g, "").trim();
      stockData = JSON.parse(cleanText);
    } else {
      throw new Error("Invalid response structure from Gemini");
    }

    return new Response(
      JSON.stringify(stockData),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});
