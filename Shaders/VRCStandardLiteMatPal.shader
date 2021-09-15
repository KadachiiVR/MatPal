Shader "Kadachii/Standard Lite MatPal"
{
	Properties
	{
		_MainTex("Albedo", 2D) = "white" {}
		_Color("Color", Color) = (1,1,1,1)

		[NoScaleOffset] _MetallicGlossMap("Metallic(R) Smoothness(A) Map", 2D) = "white" {}
		[Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 1.0
		_Glossiness("Smoothness", Range(0.0, 1.0)) = 1.0

		[NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}

		[Toggle(_EMISSION)]_EnableEmission("Enable Emission", int) = 0
		[NoScaleOffset] _EmissionMap("Emission", 2D) = "white" {}
		_EmissionColor("Emission Color", Color) = (1,1,1)

		[Toggle(_USEPALETTE)]_UsePalette("Use Palette Map", int) = 0
		[NoScaleOffset] _MaterialPalette("Material Palette", 2D) = "white" {}

		[ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 0
	}

		SubShader
		{
			Tags { "RenderType" = "Opaque" }
			LOD 200

			CGPROGRAM
			#define UNITY_BRDF_PBS BRDF2_Unity_PBS
			#include "UnityPBSLighting.cginc"

			#pragma vertex vert
			#pragma surface surf StandardMobile exclude_path:prepass exclude_path:deferred noforwardadd noshadow nodynlightmap nolppv noshadowmask

			#pragma target 3.0
			#pragma multi_compile _ _EMISSION
			#pragma multi_compile _ _USEPALETTE
			#pragma multi_compile _ _SPECULARHIGHLIGHTS_OFF
			#pragma multi_compile _GLOSSYREFLECTIONS_OFF

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
				float2 pal_uv;
				float4 color : COLOR;
			};

			struct SurfaceOutputStandardMobile
			{
				fixed3 Albedo;      // base (diffuse or specular) color
				float3 Normal;      // tangent space normal, if written
				half3 Emission;
				half Metallic;      // 0=non-metal, 1=metal
				// Smoothness is the user facing name, it should be perceptual smoothness but user should not have to deal with it.
				// Everywhere in the code you meet smoothness it is perceptual smoothness
				half Smoothness;    // 0=rough, 1=smooth
				fixed Alpha;        // alpha for transparencies
			};

			UNITY_DECLARE_TEX2D(_MainTex);
			half4 _Color;

			UNITY_DECLARE_TEX2D(_MetallicGlossMap);
			uniform half _Glossiness;
			uniform half _Metallic;

			UNITY_DECLARE_TEX2D(_BumpMap);
			uniform half _BumpScale;

			UNITY_DECLARE_TEX2D(_EmissionMap);
			half4 _EmissionColor;

			UNITY_DECLARE_TEX2D(_MaterialPalette);


			// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
			// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
			// #pragma instancing_options assumeuniformscaling
			UNITY_INSTANCING_BUFFER_START(Props)
				// put more per-instance properties here
			UNITY_INSTANCING_BUFFER_END(Props)

				// -------------------------------------

				inline half4 LightingStandardMobile(SurfaceOutputStandardMobile s, float3 viewDir, UnityGI gi)
				{
					s.Normal = normalize(s.Normal);

					half oneMinusReflectivity;
					half3 specColor;
					s.Albedo = DiffuseAndSpecularFromMetallic(s.Albedo, s.Metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

					half4 c = UNITY_BRDF_PBS(s.Albedo, specColor, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);
					UNITY_OPAQUE_ALPHA(c.a);
					return c;
				}

				inline UnityGI UnityGI_BaseMobile(UnityGIInput data, half3 normalWorld)
				{
					UnityGI o_gi;
					ResetUnityGI(o_gi);

					o_gi.light = data.light;
					o_gi.light.color *= data.atten;

					#if UNITY_SHOULD_SAMPLE_SH
						o_gi.indirect.diffuse = ShadeSHPerPixel(normalWorld, data.ambient, data.worldPos);
					#endif

					#if defined(LIGHTMAP_ON)
						// Baked lightmaps
						half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, data.lightmapUV.xy);
						half3 bakedColor = DecodeLightmap(bakedColorTex);

						#ifdef DIRLIGHTMAP_COMBINED
							fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, data.lightmapUV.xy);
							o_gi.indirect.diffuse += DecodeDirectionalLightmap(bakedColor, bakedDirTex, normalWorld);
						#else // not directional lightmap
							o_gi.indirect.diffuse += bakedColor;
						#endif
					#endif

					return o_gi;
				}

				inline half3 UnityGI_IndirectSpecularMobile(UnityGIInput data, Unity_GlossyEnvironmentData glossIn)
				{
					half3 specular;

					#ifdef _GLOSSYREFLECTIONS_OFF
						specular = unity_IndirectSpecColor.rgb;
					#else
						half3 env0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), data.probeHDR[0], glossIn);
						specular = env0;
					#endif

					return specular;
				}

				inline UnityGI UnityGlobalIlluminationMobile(UnityGIInput data, half3 normalWorld, Unity_GlossyEnvironmentData glossIn)
				{
					UnityGI o_gi = UnityGI_BaseMobile(data, normalWorld);
					o_gi.indirect.specular = UnityGI_IndirectSpecularMobile(data, glossIn);
					return o_gi;
				}

				inline void LightingStandardMobile_GI(SurfaceOutputStandardMobile s, UnityGIInput data, inout UnityGI gi)
				{
					Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.Smoothness, data.worldViewDir, s.Normal, lerp(unity_ColorSpaceDielectricSpec.rgb, s.Albedo, s.Metallic));
					gi = UnityGlobalIlluminationMobile(data, s.Normal, g);
				}

				void vert(inout AppData v, out Input o) {
					UNITY_INITIALIZE_OUTPUT(Input, o);
					o.pal_uv = v.texcoord2;
				}

				void surf(Input IN, inout SurfaceOutputStandardMobile o)
				{
					#ifdef _USEPALETTE
						float4 bounds = UNITY_SAMPLE_TEX2D(_MaterialPalette, IN.pal_uv);
						float2 inuv = (IN.uv_MainTex - floor(IN.uv_MainTex));
						float2 uv = float2(bounds.x + inuv.x * (bounds.y - bounds.x), bounds.y + inuv.x * (bounds.w - bounds.z));
					#else
						float2 uv = (IN.uv_MainTex - floor(IN.uv_MainTex) + floor(IN.pal_uv * 8.0f)) / 8.0f;
					#endif

					// Albedo comes from a texture tinted by color
					half4 albedoMap = UNITY_SAMPLE_TEX2D(_MainTex, uv) * _Color * IN.color;
					//half4 albedoMap = UNITY_SAMPLE_TEX2D(_MainTex, IN.paluv) * _Color * IN.color;
					o.Albedo = albedoMap.rgb;
					//o.Albedo = half4(uv.x, uv.y, 0, 1);

					// Metallic and smoothness come from slider variables
					half4 metallicGlossMap = UNITY_SAMPLE_TEX2D(_MetallicGlossMap, uv);
					o.Metallic = metallicGlossMap.r * _Metallic;
					o.Smoothness = metallicGlossMap.a * _Glossiness;

					o.Normal = UnpackNormal(UNITY_SAMPLE_TEX2D(_BumpMap, uv));

					#ifdef _EMISSION
						o.Emission = UNITY_SAMPLE_TEX2D(_EmissionMap, uv) * _EmissionColor;
					#endif
				}
				ENDCG
		}

			FallBack "VRChat/Mobile/Diffuse"
}
