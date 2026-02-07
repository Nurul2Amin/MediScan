import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent";

interface RequestBody {
  image_base64: string;
  mime_type: string;
}

interface Medicine {
  name: string;
  generic_name?: string;
  strength?: string;
  form?: string;
}

interface Response {
  medicines: Medicine[];
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get Gemini API key from Supabase secrets
    const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiApiKey) {
      throw new Error("GEMINI_API_KEY not configured");
    }

    // Parse request
    const { image_base64, mime_type }: RequestBody = await req.json();

    if (!image_base64 || !mime_type) {
      throw new Error("image_base64 and mime_type are required");
    }

    // Call Gemini API
    const geminiUrl = `${GEMINI_API_URL}?key=${geminiApiKey}`;
    
    const prompt = `You are an expert pharmacist and OCR system. Extract medicines from the prescription image to match a database schema. Return ONLY valid JSON matching this exact schema:
{
  "medicines": [
    {
      "name": "Brand Name (exact as written)",
      "generic_name": "Scientific/generic name (e.g., 'Napa' -> 'Paracetamol')",
      "strength": "Dosage strength (e.g., '500 mg', '10 mg/5 ml')",
      "form": "One of: Tablet, Capsule, Syrup, Suspension, Gel, Cream, Injection, Drop, Suppository, Inhaler"
    }
  ]
}
Rules:
1. 'name': Extract exact Brand Name
2. 'generic_name': Infer scientific name (CRITICAL for matching)
3. 'strength': Combine text (e.g., '500 mg', '10 mg/5 ml')
4. 'form': Standardize to one of the listed forms
5. Normalize spelling (e.g., 'Azothro' -> 'Azithromycin')
6. Ignore dosage instructions/frequency
Return ONLY the JSON object, no markdown, no code blocks.`;

    const response = await fetch(geminiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
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
              medicines: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    name: { type: "string" },
                    generic_name: { type: "string" },
                    strength: { type: "string" },
                    form: { type: "string" },
                  },
                  required: ["name"],
                },
              },
            },
            required: ["medicines"],
          },
        },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Gemini API error: ${response.status} - ${errorText}`);
    }

    const geminiData = await response.json();
    
    // Extract JSON from Gemini response
    let medicinesData: Response;
    if (geminiData.candidates?.[0]?.content?.parts?.[0]?.text) {
      const text = geminiData.candidates[0].content.parts[0].text;
      const cleanText = text.replace(/```json/g, "").replace(/```/g, "").trim();
      medicinesData = JSON.parse(cleanText);
    } else {
      throw new Error("Invalid response structure from Gemini");
    }

    return new Response(
      JSON.stringify(medicinesData),
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
