import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json()
    const { provider, model, messages, stream = false, ...rest } = body

    let apiKey = ''
    let baseUrl = ''
    let method = 'POST'
    let requestBody: any = { model, messages, stream, ...rest }

    // Helper to get random key
    const getRandomKey = (envName: string) => {
      try {
        const keys = JSON.parse(Deno.env.get(envName) || '[]')
        return keys[Math.floor(Math.random() * keys.length)]
      } catch {
        return Deno.env.get(envName) || ''
      }
    }

    switch (provider) {
      case 'groq':
        apiKey = getRandomKey('GROQ_KEYS')
        baseUrl = 'https://api.groq.com/openai/v1/chat/completions'
        break
      case 'nvidia':
        apiKey = getRandomKey('NVIDIA_KEYS')
        baseUrl = 'https://integrate.api.nvidia.com/v1/chat/completions'
        break
      case 'mistral':
        apiKey = Deno.env.get('MISTRAL_KEY') || ''
        baseUrl = 'https://api.mistral.ai/v1/chat/completions'
        break
      case 'gemini':
        apiKey = Deno.env.get('GEMINI_KEY') || ''
        // Gemini URL format: https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={apiKey}
        baseUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`
        // Gemini body doesn't use "model" inside JSON if it's in the URL
        requestBody = { contents: rest.contents || messages } 
        break
      case 'openrouter':
        const orKeys = JSON.parse(Deno.env.get('OPENROUTER_KEYS') || '{}')
        apiKey = orKeys[model] || Object.values(orKeys)[0]
        baseUrl = 'https://openrouter.ai/api/v1/chat/completions'
        break
      default:
        throw new Error(`Unsupported provider: ${provider}`)
    }

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    }
    
    if (provider !== 'gemini') {
      headers['Authorization'] = `Bearer ${apiKey}`
    }

    const response = await fetch(baseUrl, {
      method,
      headers,
      body: JSON.stringify(requestBody),
    })

    // Relay the response (streaming or json)
    if (stream) {
      // Handle streaming proxying if needed, but for now simple json
      const data = await response.text()
      return new Response(data, {
        headers: { ...corsHeaders, 'Content-Type': 'text/event-stream' },
      })
    } else {
      const data = await response.json()
      return new Response(JSON.stringify(data), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

  } catch (error) {
    console.error(`[AI-PROXY ERROR]: ${error.message}`)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
