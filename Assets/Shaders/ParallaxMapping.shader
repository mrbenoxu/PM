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

				// Unity使用的是列矩阵，如A,B,C是三个互相垂直的单位向量，则它们构建的变换矩阵为：
				// float3x3 mat = float3x3(A.x, B.x, C.x,
				//						   A.y, B.y, C.y,
				//						   A.z, B.z, C.z);
				// 这构建的是一个由ABC三个向量所构建的空间转向ABC三个向量所在的空间
				// 比如ABC三个是tangnetWS、bitangentWS和normalWS的话，那么三个向量构建的就是一个从切线空间转为世界空间的变换矩阵：
				// float3x3 tangentToWorld = float3x3(tangentWS.x, bitangentWS.x, normalWS.x,
				// 									  tangentWS.y, bitangentWS.y, normalWS.y,
				//									  tangnetWS.z, bitangentWS.z, normalWS.z);
				// 变换矩阵中旋转矩阵和统一缩放的矩阵是正立矩阵，而平移矩阵并不是正交矩阵
				// 正交矩阵的有一个特性就是它的逆矩阵等于它的转置矩阵，所以上面如果ABC所构建的是正交矩阵的话，那么它的逆矩阵为：
				// float3x3 invMat = float3x3(A.x, A.y, A.z,
				//                            B.x, B.y, B.z,
				//                            C.x, C.y, C.z);
				// 或者最常见的形式为:
				// float3x3 invMat = float3x3(A, B, C);
				// 再或者：
				// float3x3 invMat = transpose(mat);
				// 上面之所以成立就是因为正交矩阵的逆矩阵为它转置矩阵
				// 因此，如果要使用tagnentWS、bitangentWS和normalWS构建一个从世界空间到切线空间的变换矩阵的话，则矩阵为：
				// float3x3 worldToTangent = float3x3(tangentWS, bitangentWS, normalWS);
				// 或者:
				// float3x3 worldToTangent = transpose(tangentToWorld);
				// 当然上面这些成立的前提就是ABC构建的是正交矩阵，如果不是正交矩阵的话，那么就不能这么操作。
				// float3x3 objectToTangent = float3x3(v.tangentOS.xyz, 
				//                                     cross(v.normalOS, v.tangentOS.xyz) * v.tangentOS.w,
				//                                     v.normalOS.xyz);
				// o.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.positionOS));
				// 上面这个代码段是将视向量转到切空间下，但这段代码在非统一缩放下是错的。
				// 首先由模型空间下的tangentOS、bitangnetOS和normalOS构建的变换矩阵为：
				// float3x3 tangentToObject = float3x3(tangentOS.x, bitangentOS.x, normalOS.x,
				//									   tangentOS.y, bitangnetOS.y, normalOS.y,
				//									   tangentOS.z, bitangnetOS.z, normalOS.z);
				// 因为非统一缩放下构建的矩阵并不是正交矩阵，所以tangentToObject的逆矩阵并不等于转置矩阵
				// 因为inverse(tangentToObject) ~= objectToTangent; 其中inverse是一个计算逆矩阵的方法
				// 因此在平常开发过程中，一定要弄清楚当前构建的变换矩阵是否是正交矩阵，并不能盲目把转置矩阵当逆矩阵使用
			

                // 使用模型空间下的法向量、切向量和副切向量构建的是模型空间到切线空间的变换矩阵
                // TODO: 后面看了下这个应该是切线空间转为模型空间下才对
				float3 bitangentOS = normalize(cross(v.normalOS, v.tangentOS.xyz) * v.tangentOS.w);
                float3x3 objectToTangent = float3x3(
                    v.tangentOS.xyz,
                    // cross(v.normalOS, v.tangentOS.xyz) * v.tangentOS.w,
                    bitangentOS,
                    v.normalOS.xyz
                );
                o.tangentViewDir = mul(objectToTangent, ObjSpaceViewDir(v.positionOS));

                float3x3 tangentToObject = float3x3(v.tangentOS.x, bitangentOS.x, v.normalOS.x,
                                                    v.tangentOS.y, bitangentOS.y, v.normalOS.y,
                                                    v.tangentOS.z, bitangentOS.z, v.normalOS.z);
                // o.tangentViewDir = mul(tangentToObject, ObjSpaceViewDir(v.positionOS));
                o.tangentViewDir = mul(transpose(tangentToObject), ObjSpaceViewDir(v.positionOS));

				// float3x3 rotation0 = float3x3(v.tangentOS, v.bitangentOS, v.normalOS);
				// float3x3 rotation1 = float3x3(v.tangentOS.x, v.tangentOS.y, v.tangentOS.z,
				// 								v.bitangentOS.x, v.bitangentOS.y, v.bitangentOS.z,
				//								v.normalOS.x, v.normalOS.y, v.normalOS.z);

				// float3x3 rotation2 = float3x3(v.tangentOS.x, v.bitangentOS.x, v.normalOS.x,
				//								 v.tangentOS.y, v.bitangentOS.y, v.normalOS.y,
				//								 v.tangentOS.z, v.bitangentOS.z, v.normalOS.z);
			
				// 转置后矩阵的行等于原来的列，列等于原来的行
				// 所以按这么理解的话，rotation2是rotation1的转置矩阵，而rotation2是将从切线转为模型，而rotation1则就是将模型转为切线了。 
				// 但其实这种方式是错的，因为没有考虑到法线不统一缩放的情况。但如果能保证发法统一缩放就是没有问题的。


                // 上面的代码应该改为：
                // float3x3 tangentToObject = float3x3(
                    // v.tangentOS.xyz,
                    // cross(v.normalOS, v.tangentOS.xyz) * v.tangentOS.w,
                    // v.normalOS.xyz
                //);
                // o.tangentViewDir = mul(transpose(tangentToObject), ObjSpaceViewDir(v.positionOS));

                // 正交矩阵是一个每个轴既是单位向量同时相互垂直的变换矩阵，它的逆矩阵为它的转置矩阵
                // 所以在知道tangentToObject后通过转置得到它的逆矩阵objectToTangent
				// 即：objectToTangent = transpose(tangentToObject)

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
				// 应该说成三个在世界空间下两两垂直的单位向量构建一个从切线空间转到世界空间下的变换矩阵，它是一个正交矩阵
                // 进一步扩展就是任何空间下的三个正交向量可以构建出从三个向量所构建的空间转到三个向量所在的空间下

                /*
				// 求逆矩阵
				float4x4 inverse(float4x4 input) 
				{
                     #define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
                     
                     float4x4 cofactors = float4x4(
                          minor(_22_23_24, _32_33_34, _42_43_44), 
                         -minor(_21_23_24, _31_33_34, _41_43_44),
                          minor(_21_22_24, _31_32_34, _41_42_44),
                         -minor(_21_22_23, _31_32_33, _41_42_43),
                         
                         -minor(_12_13_14, _32_33_34, _42_43_44),
                          minor(_11_13_14, _31_33_34, _41_43_44),
                         -minor(_11_12_14, _31_32_34, _41_42_44),
                          minor(_11_12_13, _31_32_33, _41_42_43),
                         
                          minor(_12_13_14, _22_23_24, _42_43_44),
                         -minor(_11_13_14, _21_23_24, _41_43_44),
                          minor(_11_12_14, _21_22_24, _41_42_44),
                         -minor(_11_12_13, _21_22_23, _41_42_43),
                         
                         -minor(_12_13_14, _22_23_24, _32_33_34),
                          minor(_11_13_14, _21_23_24, _31_33_34),
                         -minor(_11_12_14, _21_22_24, _31_32_34),
                          minor(_11_12_13, _21_22_23, _31_32_33)
                     );
                     #undef minor
                     return transpose(cofactors) / determinant(input);
                }*/

				// 结论：
				// 正交矩阵的逆矩阵等于它的转置矩阵
				// 统一缩放矩阵和旋转矩阵是正交矩阵，平移矩阵不是正交矩阵

                // 引用：
                // https://learnopengl-cn.github.io/05%20Advanced%20Lighting/04%20Normal%20Mapping/
				// https://github.com/candycat1992/Unity_Shaders_Book/issues/87
				// https://github.com/candycat1992/Unity_Shaders_Book/issues/45

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
