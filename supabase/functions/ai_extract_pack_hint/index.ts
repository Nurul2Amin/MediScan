import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent";

interface RequestBody {
  image_base64: string;
  mime_type: string;
}

interface Conversion {
  unit_label: string;
  multiplier_to_base: number;
}

interface Response {
  unit_type: "pill" | "bottle" | "vial" | "tube" | "sachet" | "piece" | "ml";
  conversions: Conversion[];
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

    const { image_base64, mime_type }: RequestBody = await req.json();
    if (!image_base64 || !mime_type) {
      throw new Error("image_base64 and mime_type are required");
    }

    const prompt = `Analyze this medicine package image and extract unit type and pack size conversions. Return ONLY valid JSON:
{
  "unit_type": "pill|bottle|vial|tube|sachet|piece|ml",
  "conversions": [
    {"unit_label": "pill", "multiplier_to_base": 1},
    {"unit_label": "leaflet", "multiplier_to_base": 10},
    {"unit_label": "box", "multiplier_to_base": 100}
  ]
}
Rules:
- unit_type: primary unit (pill for tablets, ml for liquids, etc.)
- conversions: array of unit labels with multipliers relative to base unit
- base unit always has multiplier 1
- Extract from package text (e.g., "10 tablets per strip, 10 strips per box" = pill:1, strip:10, box:100)
Return ONLY the JSON object, no markdown.`;

    const geminiUrl = `${GEMINI_API_URL}?key=${geminiApiKey}`;
    
    const response = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: prompt },
              {
                inline_data: {
                  mime_type: mime_type,
                  data: image_base64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          response_mime_type: "application/json",
          response_schema: {
            type: "object",
            properties: {
              unit_type: {
                type: "string",
                enum: ["pill", "bottle", "vial", "tube", "sachet", "piece", "ml"],
              },
              conversions: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    unit_label: { type: "string" },
                    multiplier_to_base: { type: "number" },
                  },
                  required: ["unit_label", "multiplier_to_base"],
                },
              },
            },
            required: ["unit_type", "conversions"],
          },
        },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Gemini API error: ${response.status} - ${errorText}`);
    }

    const geminiData = await response.json();
    let packData: Response;
    
    if (geminiData.candidates?.[0]?.content?.parts?.[0]?.text) {
      const text = geminiData.candidates[0].content.parts[0].text;
      const cleanText = text.replace(/```json/g, "").replace(/```/g, "").trim();
      packData = JSON.parse(cleanText);
    } else {
      throw new Error("Invalid response structure from Gemini");
    }

    return new Response(
      JSON.stringify(packData),
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
