Shader "Unlit/ParallaxMapping"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _ParallaxTex ("Parallax Texture", 2D) = "white" {}
        _NormalTex ("Normal Texture", 2D) = "bump" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
	            float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 tangentViewDir : TEXCOORD1;
                float4 vertex : SV_POSITION;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
            };

            sampler2D _MainTex;
            sampler2D _NormalTex;
            float4 _MainTex_ST;

            float3 ObjSpaceViewDir (float4 v) 
            {
                float3 objSpaceCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos.xyz, 1)).xyz;
                return objSpaceCameraPos - v.xyz;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.positionOS);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // 使用模型空间下的法向量、切向量和副切向量构建的是模型空间到切线空间的变换矩阵
                // TODO: 后面看了下这个应该是切线空间转为模型空间下才对
                float3x3 objectToTangent = float3x3(
                    v.tangentOS.xyz,
                    cross(v.normalOS, v.tangentOS.xyz) * v.tangentOS.w,
                    v.normalOS.xyz
                );
                o.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.positionOS));

                // 上面的代码应该改为：
                // float3x3 tangentToObject = float3x3(
                    // v.tangentOS.xyz,
                    // cross(v.normalOS, v.tangentOS.xyz) * v.tangentOS.w,
                    // v.normalOS.xyz
                //);
                // o.tangentViewDir = mul(transpose(objectToTangent), ObjSpaceViewDir(v.positionOS));

                // 正交矩阵是一个每个轴既是单位向量同时相互垂直的变换矩阵，它的逆矩阵为它的转置矩阵
                // 所以在知道tangentToObject后通过转置得到它的逆矩阵objectToTangent

                // 使用世界空间下的法向量、切向量和副切向量构建的是世界空间到切线空间的变换矩阵
                // TODO: 我后面又看了下，感觉应该是将切线空间转为世界空间下
                VertexNormalInputs vertexTBN = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                // float3x3 worldToTangent = float3x3(
                //     vertexTBN.tangentWS,
                //     vertexTBN.bitangentWS,
                //     vertexTBN.normalWS
                // );
                // float3 positionWS = TransformObjectToWorld(v.positionOS);
                // float3 viewDir = GetWorldSpaceViewDir(positionWS);
                // o.tangentViewDir = mul(worldToTangent, viewDir);

                // 上面的代码要改为：
                // float3x3 tangentToWorld = float3x3(vertexTBN.tangentWS, vertexTBN.bitangentWS, vertexTBN.normalWS);
                // float3 positionWS = TransformObjectToWorld(v.positionOS);
                // float3 viewDir = GetWorldSpaceViewDir(positionWS);
                // o.tangentViewDir = mul(transpose(tangentToWorld), viewDir)

                // NOTE: 在开发过程中，UNITY是有提供一个将法向从模型空间转到世界空间的变换矩阵
                // TransformObjectToWorldNormal是将法向量从模型空间转为世界空间下
                // 之所有提供这个是因为法线变换使用的是原变换矩阵的逆转置矩阵

                // v.normalOS是模型空间下的一个向量，不过它和v.tangentOS确是可以构建出一个切线空间出来
                // 所以三个在世界空间下的正交向量（单位向量且互相垂直）构建构建一个从世界空间转到这三个向量所构建的空间下
                // 上面这话是错的，应该是：三个在世界空间下的正交向量（单位向量且互相垂直）构建一个从切线空间转到世界空间下
                // 进一步扩展就是任何空间下的三个正交向量可以构建出从三个向量所构建的空间转到三个向量所在的空间下

                // 引用：
                // https://learnopengl-cn.github.io/05%20Advanced%20Lighting/04%20Normal%20Mapping/

                // 

                /*
                // vert
                // output the tangent space matrix
                o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
                o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);

                // frag
                half3 tnormal = UnpackNormal(tex2D(_NormalMap, i.uv));
                // !!! transform normal from tangent to world space
                half3 worldNormal;
                worldNormal.x = dot(i.tspace0, tnormal);
                worldNormal.y = dot(i.tspace1, tnormal);
                worldNormal.z = dot(i.tspace2, tnormal);
                
                */
        
                
                o.tangentWS = vertexTBN.tangentWS;
                o.bitangentWS = vertexTBN.bitangentWS;
                o.normalWS = vertexTBN.normalWS;
				

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half3 tangentViewDir = normalize(i.tangentViewDir);
                return float4(tangentViewDir * 0.5 + 0.5, 1);

                float3x3 tangentToWorld = float3x3(i.tangentWS, i.bitangentWS, i.normalWS);
                float3x3 worldToTangent = transpose(tangentToWorld);

                half4 normal = tex2D(_NormalTex, i.uv);
                normal = normal * 2.0 - 1.0;
                half3 worldNormal = mul(tangentToWorld, normal.xyz);
                return float4(worldNormal * 0.5 + 0.5, 1);

                Light light = GetMainLight();
                half3 diffuse = LightingLambert(float3(1, 1, 1), light.direction, worldNormal.xyz);

                half4 col = tex2D(_MainTex, i.uv) * float4(diffuse, 0);
                return col;
            }
            ENDHLSL
        }
    }
}
