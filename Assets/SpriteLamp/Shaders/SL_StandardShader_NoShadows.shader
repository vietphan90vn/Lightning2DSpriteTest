﻿// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'
// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

// Shader for Unity integration with SpriteLamp. Currently the 'kitchen sink'
// shader - contains all the effects from Sprite Lamp's preview window using the default shader.
// Based on a shader by Steve Karolewics & Indreams Studios. Final version by Finn Morgan
// Note: Finn is responsible for spelling 'colour' with a U throughout this shader. Find/replace if you must.


Shader "SpriteLamp/Standard_NoShadows"
{
    Properties
    {
        _MainTex ("Diffuse Texture", 2D) = "white" {}		//Alpha channel is plain old transparency
        _NormalDepth ("Normal Depth", 2D) = "bump" {} 		//Normal information in the colour channels, depth in the alpha channel.
        _SpecGloss ("Specular Gloss", 2D) = "" {}			//Specular colour in the colour channels, and glossiness in the alpha channel.
        _AmbientOcclusion ("Ambient Occlusion", 2D) = "" {} //A greyscale value for precomputed ambient occlusion - not very compact.
        _EmissiveColour ("Emissive colour", 2D) = "" {}		//A colour image that is simply added over the final colour. Might eventually have AO packed into its alpha channel.
       
        _SpecExponent ("Specular Exponent", Range (1.0,50.0)) = 10.0		//Multiplied by the alpha channel of the spec map to get the specular exponent.
        _SpecStrength ("Specular Strength", Range (0.0,5.0)) = 1.0		//Multiplier that affects the brightness of specular highlights
        _AmplifyDepth ("Amplify Depth", Range (0,1.0)) = 0.0	//Affects the 'severity' of the depth map - affects shadows (and shading to a lesser extent).
        _CelShadingLevels ("Cel Shading Levels", Float) = 0		//Set to zero to have no cel shading.
        _TextureRes("Texture Resolution", Vector) = (256, 256, 0, 0)	//Leave this to be set via a script.
        _AboveAmbientColour("Upper Ambient Colour", Color) = (0.3, 0.3, 0.3, 0.3)	//Ambient light coming from above.
        _BelowAmbientColour("Lower Ambient Colour", Color) = (0.1, 0.1, 0.1, 0.1)	//Ambient light coming from below.
        _LightWrap("Wraparound lighting", Range (0,1.0)) = 0.0	//Higher values of this will cause diffuse light to 'wrap around' and light the away-facing pixels a bit.
        _AmbientOcclusionStrength("Ambient Occlusion Strength", Range (0,1.0)) = 0.0	//Determines how strong the effect of the ambient occlusion map is.
        _EmissiveStrength("Emissive strength", Range(0, 1.0)) = 0.0	//Emissive map is multiplied by this.
        _AttenuationMultiplier("Attenuation multiplier", Range(0.1, 5.0)) = 1.0	//Distance is multiplied by this for purposes of calculating attenuation
        _SpotlightHardness("Spotlight hardness", Range(1.0, 10.0)) = 2.0	//Higher number makes the edge of a spotlight harder.
    }

    SubShader
    {
		Tags
		{ 
			"Queue"="Transparent" 
			"IgnoreProjector"="True" 
			"RenderType"="Transparent" 
			"PreviewType"="Plane"
			"CanUseSpriteAtlas"="True"
		}

		Cull Off
		Lighting Off
		ZWrite Off
		Fog { Mode Off }
		Blend SrcAlpha OneMinusSrcAlpha
		AlphaTest NotEqual 0.0
		
        Pass
        {    
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM

            #pragma vertex vert  
            #pragma fragment frag 

			#include "UnityCG.cginc"
			#include "AutoLight.cginc"

            uniform sampler2D _MainTex;
            uniform sampler2D _NormalDepth;
            uniform sampler2D _SpecGloss;
            uniform sampler2D _AmbientOcclusion;
            uniform sampler2D _EmissiveColour;
            uniform float4 _AboveAmbientColour;
            uniform float4 _BelowAmbientColour;
            uniform float _AmbientOcclusionStrength;
            uniform float _EmissiveStrength;
            uniform float _AttenuationMultiplier;
            uniform float4 _LightColor0;
            uniform float _SpecExponent;
            uniform float _AmplifyDepth;
            uniform float _CelShadingLevels;
            uniform float4 _TextureRes;
            uniform float _LightWrap;
            uniform float _SpecStrength;
            uniform float4x4 unity_WorldToLight; // transformation
			uniform float _SpotlightHardness;
         	
           
            struct VertexInput
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float4 uv : TEXCOORD0;
            };

            struct VertexOutput
            {
                float4 pos : POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                float4 posWorld : TEXCOORD1;
                float4 posLight : TEXCOORD2;
            };

            VertexOutput vert(VertexInput input) 
            {                
                VertexOutput output;

                output.pos = UnityObjectToClipPos(input.vertex);
                output.posWorld = mul(unity_ObjectToWorld, input.vertex);

                output.uv = input.uv.xy;
                output.color = input.color;
				output.posLight = mul(unity_WorldToLight, output.posWorld);
                return output;
            }

            float4 frag(VertexOutput input) : COLOR
            {
                float4 diffuseColour = tex2D(_MainTex, input.uv);
                float4 normalDepth = tex2D(_NormalDepth, input.uv);
                float ambientOcclusion = tex2D(_AmbientOcclusion, input.uv).r;
                float3 emissiveColour = tex2D(_EmissiveColour, input.uv).rgb;		
				float4 specGlossValues = tex2D(_SpecGloss, input.uv);
                
                float4 ambientResult;
                
                ambientOcclusion = (ambientOcclusion * _AmbientOcclusionStrength) + (1.0 - _AmbientOcclusionStrength);
        
                float3 worldNormalDirection = (normalDepth.xyz - 0.5) * 2.0;
                
                worldNormalDirection = float3(mul(float4(worldNormalDirection, 1.0), unity_WorldToObject).xyz);
                
                float upness = worldNormalDirection.y * 0.5 + 0.5; //'upness' - 1.0 means the normal is facing straight up, 0.5 means horizontal, 0.0 straight down, etc.
                
                float4 ambientColour = (_BelowAmbientColour * (1.0 - upness) + _AboveAmbientColour * upness) * ambientOcclusion;
                
                
                ambientResult = float4(ambientColour * diffuseColour + float4(emissiveColour * _EmissiveStrength, 0.0));
                
                //We have to calculate illumination here too, because the first light that gets rendered
                //gets folded into the ambient pass apparently.
                //Get the real vector for the normal, 
		        float3 normalDirection = (normalDepth.xyz - 0.5) * 2.0;
                normalDirection.z *= -1.0;
                normalDirection = normalize(normalDirection);
				
				
				
				
                float depthColour = normalDepth.a;
                
                
                //For per-texel lighting, we recreate the world position based on the sprite's UVs...
                float2 positionOffset = input.uv;
                float2 roundedUVs = input.uv;
                
                //Intervening here to round the UVs to the nearest 1.0/TextureRes to clamp the world position
                //to the nearest pixel...
                roundedUVs *= _TextureRes.xy;
                roundedUVs = floor(roundedUVs);
                roundedUVs /= _TextureRes.xy;
                
                float3 posWorld = input.posWorld.xyz;

                posWorld.z -= depthColour * _AmplifyDepth;	//The fragment's Z position is modified based on the depth map value.
                float3 vertexToLightSource;
                float3 lightDirection;
                float attenuation;
				if (0.0 == _WorldSpaceLightPos0.w) // directional light?
				{
					//This handles directional lights
					lightDirection = float3(mul(float4(_WorldSpaceLightPos0.xyz, 1.0), unity_ObjectToWorld).xyz);
					lightDirection = normalize(lightDirection);
				}
				else
				{
					vertexToLightSource = float3(_WorldSpaceLightPos0.xyz) - posWorld;
					lightDirection = float3(mul(float4(vertexToLightSource, 1.0), unity_ObjectToWorld).xyz);
					lightDirection = normalize(lightDirection);
				}
				UNITY_LIGHT_ATTENUATION(attenVal, input, posWorld);
				attenuation = attenVal;
                                
                
                float aspectRatio = _TextureRes.x / _TextureRes.y;           
                
                
                // Compute diffuse part of lighting
                float normalDotLight = dot(normalDirection, lightDirection);
                
                //Slightly awkward maths for light wrap.
                float diffuseLevel = clamp(normalDotLight + _LightWrap, 0.0, _LightWrap + 1.0) / (_LightWrap + 1.0) * attenuation;
                
                // Compute specular part of lighting
                float specularLevel;
                if (normalDotLight < 0.0)
                {
                    // Light is on the wrong side, no specular reflection
                    specularLevel = 0.0;
                }
                else
                {
                    // For the moment, since this is 2D, we'll say the view vector is always (0, 0, -1).
                    //This isn't really true when you're not using a orthographic camera though. FIXME.
                    float3 viewDirection = float3(0.0, 0.0, -1.0);
                    specularLevel = attenuation * pow(max(0.0, dot(reflect(-lightDirection, normalDirection),
                        viewDirection)), _SpecExponent * specGlossValues.a) * 0.4;
                }

                // Add cel-shading if enough levels were specified
                if (_CelShadingLevels >= 2.0)
                {
                    diffuseLevel = floor(diffuseLevel * _CelShadingLevels) / (_CelShadingLevels - 0.5);
                    specularLevel = floor(specularLevel * _CelShadingLevels) / (_CelShadingLevels - 0.5);
                }

				//The easy bits - assemble the final values based on light and map colours and combine.
                float3 diffuseReflection = diffuseColour.xyz * input.color.xyz * _LightColor0.xyz * diffuseLevel;
                float3 specularReflection = _LightColor0.xyz * input.color.xyz * specularLevel * specGlossValues.rgb * _SpecStrength;
                
                float4 finalColour = float4(diffuseReflection + specularReflection, diffuseColour.a) + ambientResult;
                finalColour.a = diffuseColour.a;
                return finalColour;
                

                //return ambientResult;
            }

            ENDCG
        }

        Pass
        {    
            Tags { "LightMode" = "ForwardAdd" }
            Blend One One // additive blending 

            CGPROGRAM

            #pragma vertex vert  
            #pragma fragment frag 
			#pragma target 3.0

			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#pragma multi_compile_lightpass

            // User-specified properties
            uniform sampler2D _MainTex;
            uniform sampler2D _NormalDepth;
            uniform sampler2D _SpecGloss;
            uniform float4 _LightColor0;
            uniform float _SpecExponent;
            uniform float _AmplifyDepth;
            uniform float _CelShadingLevels;
            uniform float4 _TextureRes;
            uniform float _LightWrap;
            uniform float _AttenuationMultiplier;
            uniform float _SpecStrength;
            
			uniform float _SpotlightHardness;

            struct VertexInput
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float4 uv : TEXCOORD0;
            };

            struct VertexOutput
            {
                float4 pos : POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                float4 posWorld : TEXCOORD1;
                float4 posLight : TEXCOORD2;
            };

            VertexOutput vert(VertexInput input)
            {
                VertexOutput output;

                output.pos = UnityObjectToClipPos(input.vertex);
                output.posWorld = mul(unity_ObjectToWorld, input.vertex);

                output.uv = input.uv.xy;
                output.color = input.color;
#ifndef DIRECTIONAL
				output.posLight = mul(unity_WorldToLight, output.posWorld);
#endif
                return output;
            }

            float4 frag(VertexOutput input) : COLOR
            {
            	//Do texture reads first, because in theory that's a bit quicker...
                float4 diffuseColour = tex2D(_MainTex, input.uv);
				float4 normalDepth = tex2D(_NormalDepth, input.uv);				
				float4 specGlossValues = tex2D(_SpecGloss, input.uv);
				
				//Get the real vector for the normal, 
		        float3 normalDirection = (normalDepth.xyz - 0.5) * 2.0;
                normalDirection.z *= -1.0;
                normalDirection = normalize(normalDirection);
				
				
                float depthColour = normalDepth.a;
                
                //For per-texel lighting, we recreate the world position based on the sprite's UVs...
                float2 positionOffset = input.uv;
                float2 roundedUVs = input.uv;
                
                //Intervening here to round the UVs to the nearest 1.0/TextureRes to clamp the world position
                //to the nearest pixel...
                roundedUVs *= _TextureRes.xy;
                roundedUVs = floor(roundedUVs);
                roundedUVs /= _TextureRes.xy;
                
                
                float3 posWorld = input.posWorld.xyz;

                posWorld.z -= depthColour * _AmplifyDepth;	//The fragment's Z position is modified based on the depth map value.
                float3 vertexToLightSource;
                float3 lightDirection;
                float attenuation;
				if (0.0 == _WorldSpaceLightPos0.w) // directional light?
				{
					//This handles directional lights
					lightDirection = float3(mul(float4(_WorldSpaceLightPos0.xyz, 1.0), unity_ObjectToWorld).xyz);
					lightDirection = normalize(lightDirection);
				}
				else
				{
					vertexToLightSource = float3(_WorldSpaceLightPos0.xyz) - posWorld;
					lightDirection = float3(mul(float4(vertexToLightSource, 1.0), unity_ObjectToWorld).xyz);
					lightDirection = normalize(lightDirection);
				}
				UNITY_LIGHT_ATTENUATION(attenVal, input, posWorld);
				attenuation = attenVal;
                                
                
                float aspectRatio = _TextureRes.x / _TextureRes.y;
                
                

                // Compute diffuse part of lighting
                float normalDotLight = dot(normalDirection, lightDirection);
                
                //Slightly awkward maths for light wrap.
                float diffuseLevel = clamp(normalDotLight + _LightWrap, 0.0, _LightWrap + 1.0) / (_LightWrap + 1.0) * attenuation;
                
                // Compute specular part of lighting
                float specularLevel;
                if (normalDotLight < 0.0)
                {
                    // Light is on the wrong side, no specular reflection
                    specularLevel = 0.0;
                }
                else
                {
                    // For the moment, since this is 2D, we'll say the view vector is always (0, 0, -1).
                    //This isn't really true when you're not using a orthographic camera though. FIXME.
                    float3 viewDirection = float3(0.0, 0.0, -1.0);
                    specularLevel = attenuation * pow(max(0.0, dot(reflect(-lightDirection, normalDirection),
                        viewDirection)), _SpecExponent * specGlossValues.a) * 0.4;
                }

                // Add cel-shading if enough levels were specified
                if (_CelShadingLevels >= 2.0)
                {
                    diffuseLevel = floor(diffuseLevel * _CelShadingLevels) / (_CelShadingLevels - 0.5);
                    specularLevel = floor(specularLevel * _CelShadingLevels) / (_CelShadingLevels - 0.5);
                }

				//The easy bits - assemble the final values based on light and map colours and combine.
                float3 diffuseReflection = diffuseColour.xyz * input.color * _LightColor0.xyz * diffuseLevel;
                float3 specularReflection = _LightColor0.xyz * input.color * specularLevel * specGlossValues.rgb * _SpecStrength;
                return float4((diffuseReflection + specularReflection) * diffuseColour.a, diffuseColour.a);
                
             }

             ENDCG
        }
    }
    // The definition of a fallback shader should be commented out 
    // during development:
     Fallback "Transparent/Diffuse"
}