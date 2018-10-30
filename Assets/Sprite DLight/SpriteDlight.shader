Shader "Sprites/SpriteDlight"
{
	Properties
	{
		[PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
		_Color ("Tint", Color) = (1,1,1,1)
		_CelRamp ("Cel shading ramp", 2D) = "white" {}
		[MaterialToggle] PixelSnap ("Pixel snap", Float) = 0
		[MaterialToggle] _CelShading ("Cel Shading", Float) = 1
		_BumpMap("Normal Map", 2D) = "bump" {}
		_NormalScale("Normal Scale", FLoat) = 1
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
		Blend One OneMinusSrcAlpha

		CGPROGRAM
		//#pragma surface surf Lambert vertex:vert nofog keepalpha
		#pragma surface surf CustomLambert alpha vertex:vert
		#pragma multi_compile _ PIXELSNAP_ON

		sampler2D _MainTex;
		fixed4 _Color;
		sampler2D _CelRamp;
		sampler2D _BumpMap;
		fixed _NormalScale;
		fixed _CelShading;

		struct Input
		{
			float2 uv_MainTex;
			fixed4 color;
			float2 uv_BumpMap;
		};
		
		half4 LightingCustomLambert (SurfaceOutput s, half3 lightDir, half3 viewDir, half atten) {
			half NdotL = dot (s.Normal, lightDir);
			half4 c;
			
			if( _CelShading > .5)
				c.rgb = (s.Albedo * _LightColor0.rgb  * (tex2D (_CelRamp, half2 (NdotL * 0.5 + 0.5, 0) ))) * (atten);
			else
				c.rgb = s.Albedo * _LightColor0.rgb * (NdotL * atten);
			
			c.a = s.Alpha;
			return c;
		}

		void vert (inout appdata_full v, out Input o)
		{
			#if defined(PIXELSNAP_ON)
			v.vertex = UnityPixelSnap (v.vertex);
			#endif
			
			UNITY_INITIALIZE_OUTPUT(Input, o);
			o.color = v.color * _Color;
		}

		void surf (Input IN, inout SurfaceOutput o)
		{
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * IN.color;
			fixed4 a = c * UNITY_LIGHTMODEL_AMBIENT;
			o.Albedo = a.rgb * c.a;
			o.Alpha = c.a;
			
			fixed4 packednormal = tex2D (_BumpMap, IN.uv_BumpMap);
			fixed3 normal;
			normal.xy = packednormal.wy * 2 - 1;
			normal.xy *= _NormalScale;
			normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
			
			o.Normal = normal;
		}
		ENDCG
	}
}
