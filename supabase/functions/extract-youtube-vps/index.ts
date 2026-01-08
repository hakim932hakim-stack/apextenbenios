// NOTE: Disable "Enforce JWT verification" in Supabase Dashboard for this function
// Dashboard -> Edge Functions -> extract-youtube-vps -> Settings -> Enforce JWT verification: OFF

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RENDER_API_URL = 'https://youtube-extractor-render.onrender.com/extract';
const INVIDIOUS_INSTANCES = [
    'https://invidious.nerdvpn.de',
    'https://invidious.jing.rocks',
    'https://inv.nadeko.net',
];

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const { videoId } = await req.json();

        if (!videoId) {
            return new Response(
                JSON.stringify({ error: 'videoId required' }),
                {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                }
            );
        }

        console.log('[Supabase Edge] Calling VPS for videoId:', videoId);

        // TRY 1: Render API
        try {
            const vpsResponse = await fetch(RENDER_API_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ videoId }),
            });

            if (vpsResponse.ok) {
                const data = await vpsResponse.json();

                if (data.success && data.url) {
                    console.log('[Supabase Edge] Render SUCCESS');
                    return new Response(
                        JSON.stringify({
                            videoUrl: data.url,
                            audioUrl: data.url,
                            quality: '1080p',
                            source: 'render-backend'
                        }),
                        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                    );
                }
            }
            console.log('[Supabase Edge] Render failed, trying Invidious...');
        } catch (renderError) {
            console.log('[Supabase Edge] Render error:', renderError.message);
        }

        // If Render fails and Fallback is disabled, return error
        throw new Error('Video yasaklı veya çıkartılamadı (Fallback Disabled)');

    } catch (error) {
        console.error('[Supabase Edge] Error:', error);

        return new Response(
            JSON.stringify({
                error: error.message || 'Unknown error',
                details: 'VPS extraction failed'
            }),
            {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            }
        );
    }
});
