Shader "Kadachii/Standard MatPal"
{
	Properties
	{
		_Padding("Padding (miliUVs)", float) = 0
		_Tiles("Tiles", int) = 4
		_MainTex("Albedo", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)

		[NoScaleOffset] _MetallicGlossMap("Metallic(R) Smoothness(A) Map", 2D) = "white" {}
		[Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 1.0
		_Glossiness("Smoothness", Range(0.0, 1.0)) = 1.0

		[NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}

		[Toggle(_EMISSION)]_EnableEmission("Enable Emission", int) = 0
		[NoScaleOffset] _EmissionMap("Emission", 2D) = "white" {}
		_EmissionColor("Emission Color", Color) = (1,1,1)

		[NoScaleOffset] _OcclusionMap("Ambient Occlusion", 2D) = "white" {}

		//[NoScaleOffset] _MaterialPalette("Material Palette", 2D) = "white" {}

		[ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 0
	}

		SubShader
		{
			Tags { "RenderType" = "Opaque" }
			LOD 200

			CGPROGRAM


			#pragma vertex vert
			//#pragma surface surf StandardMobile exclude_path:prepass exclude_path:deferred noforwardadd noshadow nodynlightmap nolppv noshadowmask
			#pragma surface surf Standard fullforwardshadows

			#pragma target 4.5

			// -------------------------------------

			struct AppData
			{
				float4 vertex : POSITION;
				float2 texcoord : TEXCOORD0;
				float2 texcoord1 : TEXCOORD1;
				float2 texcoord2 : TEXCOORD2;
				float3 normal : NORMAL;
				float4 tangent: TANGENT;
				float4 color: COLOR;
			};

			struct Input
			{
				float2 uv_MainTex;
				float2 minUv;
				//float2 uvMax;
				float4 color : COLOR;
				float2 tileSize;
				float2 padding;
			};
			/*
			struct SurfaceOutputStandard
			{
				fixed3 Albedo;      // base (diffuse or specular) color
				float3 Normal;      // tangent space normal, if written
				half3 Emission;
				half Metallic;      // 0=non-metal, 1=metal
				// Smoothness is the user facing name, it should be perceptual smoothness but user should not have to deal with it.
				// Everywhere in the code you meet smoothness it is perceptual smoothness
				half Smoothness;    // 0=rough, 1=smooth
				fixed Alpha;        // alpha for transparencies
			};*/


			uniform sampler2D _MainTex;
			float4 _Color;
			uniform int _Tiles;
			uniform float _Padding;

			uniform sampler2D _MetallicGlossMap;
			uniform half _Glossiness;
			uniform half _Metallic;

			uniform sampler2D _BumpMap;
			uniform half _BumpScale;

			uniform sampler2D _EmissionMap;
			half3 _EmissionColor;

			uniform sampler2D _OcclusionMap;
			//UNITY_DECLARE_TEX2D(_MaterialPalette);


			// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
			// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
			// #pragma instancing_options assumeuniformscaling
			UNITY_INSTANCING_BUFFER_START(Props)
				// put more per-instance properties here
			UNITY_INSTANCING_BUFFER_END(Props)


			float myfmod(float x, float y)
			{
				return x - y * floor(x / y);
			}

			float2 myfmod(float2 x, float2 y)
			{
				return x - y * floor(x / y);
			}

			void vert(inout AppData v, out Input o)
			{
				UNITY_INITIALIZE_OUTPUT(Input, o);
				float2 tilesPerSide = float2(_Tiles, _Tiles);
				o.padding = float2(_Padding, _Padding) / 1000.0f;
				float2 baseTileSize = rcp(tilesPerSide);
				o.tileSize = baseTileSize - (2.0f * o.padding);
				o.minUv = v.texcoord2 - myfmod(v.texcoord2, baseTileSize) + o.padding;
			}
			/*
			void vert(inout AppData v, out Input o) {
				UNITY_INITIALIZE_OUTPUT(Input, o);
				o.pal_uv = v.texcoord2;
				float texSize = float(_TexSize);
				float texSize2D = float2(texSize, texSize);
				float tilesPerSide = float(_Tiles);
				float padding = float(_Padding) / texSize;
				//float padding = ((float(_Padding) / texSize) - 0.00048828125f) * 1000000000.0f; // just for sean
				//float padding = 0.00048828125f;
				float2 padding2D = float2(padding, padding);
				o.padding = padding2D;
				float baseTileSize = 1.0f / tilesPerSide;
				float tilesize = baseTileSize - (2 * padding);
				//tilesize = (tilesize - 0.2490234375f) * 50000.0f; // sanity czech
				float2 tilesize2D = float2(tilesize, tilesize);
				float2 baseTileSize2D = float2(baseTileSize, baseTileSize);
				//o.tilesize = float2(0.25f, 0.25f);
				//o.tilesize = float2(0.2490234375f, 0.2490234375f);
				//o.tilesize = float2((1.0f + (2 * padding)) / tilesPerSide, (1.0f + (2 * padding)) / tilesPerSide);
				o.tilesize = tilesize2D;
				o.basetilesize = baseTileSize2D;
				//o.tilesize = ((float2(1.0f / tilesPerSide, 1.0f / tilesPerSide) - (2 * padding2D)) - float2(0.2490234375f, 0.2490234375f)) * 500.0f; // just for sean
				float2 min_uv = v.texcoord2 - myfmod(v.texcoord2, baseTileSize2D) + padding2D;
				o.min_uv = min_uv;
			}
			*/


			void surf(Input IN, inout SurfaceOutputStandard o)
			{
				//float2 uvMin = IN.pal_uv - myfmod(IN.pal_uv, IN.tilesize) + IN.padding;
				float2 uv = IN.minUv + myfmod(IN.uv_MainTex, IN.tileSize);
				float dx = ddx(IN.uv_MainTex.x);
				float dy = ddy(IN.uv_MainTex.y);

				//uv = IN.uvMax;

				// Albedo comes from a texture tinted by color
				float4 albedoMap = tex2Dgrad(_MainTex, uv, dx, dy) * _Color * IN.color;
				o.Albedo = albedoMap.rgb;

				// Metallic and smoothness come from slider variables
				half4 metallicGlossMap = tex2Dgrad(_MetallicGlossMap, uv, dx, dy);
				o.Metallic = metallicGlossMap.r * _Metallic;
				o.Smoothness = metallicGlossMap.a * _Glossiness;

				o.Normal = UnpackNormal(tex2Dgrad(_BumpMap, uv, dx, dy));

				o.Emission = tex2Dgrad(_EmissionMap, uv, dx, dy) * _EmissionColor;
				o.Occlusion = tex2Dgrad(_OcclusionMap, uv, dx, dy);
			}
			ENDCG
		}

			FallBack "VRChat/Mobile/Diffuse"
}

