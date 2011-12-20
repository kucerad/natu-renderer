#version 120
#define SHADOW_TRESHOLD 0.0001
#define ALPHA_TRESHOLD 0.5
#define ONE2    vec2(1.0,1.0)
#define EPSILON 0.0001
#define EPSILONVEC vec2(EPSILON, EPSILON)
uniform sampler2D	colorMap;
uniform sampler2D	branch_noise_tex;
uniform sampler2D	leaf_noise_tex;
uniform sampler2D	normalMap;
uniform	sampler2D   dataMap;
uniform sampler2D   depthMap;
uniform sampler2D	seasonMap;
uniform sampler2D	lod_data_tex;
uniform float		season;
uniform float		time;
uniform	vec2		movementVectorA;
uniform	vec2		movementVectorB;
uniform vec2		window_size;

uniform float		varA;
uniform float		scale;
uniform float		bias;

uniform vec4		wood_amplitudes;
uniform vec4		wood_frequencies;
uniform float		leaf_amplitude;
uniform float		leaf_frequency;
uniform int			shadowMappingEnabled;
uniform float		shift;
uniform float		transition_control;

varying vec3		eyeDir;
varying vec3		normalDir;
varying vec3		normal_es;
varying vec3		tangent_es;

varying vec3		lightDir_ts;
varying vec3		eyeDir_ts;
varying	float		alpha;

varying vec2		sliceDesc;

varying mat3		TBN_Matrix;

varying vec3		colorVar;
varying float		mv_time;
varying float		time_offset_v;

uniform float		MultiplyAmbient			;
uniform float		MultiplyDiffuse			;
uniform float		MultiplySpecular		;
uniform float		MultiplyTranslucency	;

uniform float		branch_count;
uniform float		near;
uniform	float		far;
uniform int			show_slice;
uniform int			show_sliceSet;
varying vec3		v_wind_dir_ts;
uniform float		wind_strength;
#define sliceCnt		3
#define sliceSetsCnt	3
#define	texCols			3.0
			 
float		fogFactor;


uniform sampler2DShadow shadowMap;
varying vec4	lightSpacePosition;
vec4 lpos;

const float infinity = 999999999;
float getShadow(vec2 position, vec2 offset, float depth){
	return shadow2D(shadowMap, vec3(position+offset*0.001,depth-SHADOW_TRESHOLD)).r; 
}

float getShadowIntensity(vec4 sm_pos){
	float res = getShadow(sm_pos.xy, vec2(0.0, 0.0), sm_pos.z) * 2.0;
	res += getShadow(sm_pos.xy, vec2(1.0, 0.0), sm_pos.z);
	res += getShadow(sm_pos.xy, vec2(-1.0, 0.0), sm_pos.z);
	res += getShadow(sm_pos.xy, vec2(0.0, 1.0), sm_pos.z);
	res += getShadow(sm_pos.xy, vec2(0.0, -1.0), sm_pos.z);
	return res/6.0;
}
/*
float getDepth(vec2 coords){
	if (clamp(coords.xy, 0.0, 1.0)!= coords.xy){
		return infinity; // infinity
	}

	float depth =  texture2D(shadowMap, coords.xy).x;
	if (depth>=1.0){
		return infinity;
	}
	return depth;
}
*/

void animateBranch(inout vec2 position, in float bid, in float time, in float offset, in float texCol, in float wood_a, in float wood_f, in vec3 wind_d, in float wind_s){
	vec2 mv;
	vec2 corr_s;
	vec2 corr_r;
	float x_val;
	vec2 amp;
	vec4 b_data0;
	vec4 b_data1;
	vec4 b_data2;
	vec4 b_data3;
	vec2 o;
	vec2 t; 
	vec3 r; 
	vec3 s; 
	float l;
	b_data0 = texture2D(lod_data_tex, vec2((0.5+offset)*texCol, bid));
	b_data1 = texture2D(lod_data_tex, vec2((1.5+offset)*texCol, bid));
	b_data2 = texture2D(lod_data_tex, vec2((2.5+offset)*texCol, bid));
	//b_data3 = texture2D(lod_data_tex, vec2((3.5+offset)*texCol, branchID));
	o = b_data0.xy;
	mv = b_data0.zw;
	r = b_data1.xyz;
	s = b_data2.xyz;
	t = cross(s,r).xy;
	l = b_data1.w;
		
	// get x value on the projected branch

	// naive solution = distance to projected origin / branch projected length
	// PROBLEMS:
	// - what about branches pointing to the observer? - projected length is near 0
	// - even pixels close to projected origin can be very far in terms of x
	vec2 distVector = abs(position-o);
	//offset = 0.0; //1.0 - length(t.xy);
	//x_val = min(1.0, offset + length(distVector)/l);
	x_val = min(1.0, length(distVector)/l);
	//color = vec4(x_val);
	vec2 w = vec2(dot(r, wind_d) * wind_s, dot(s, wind_d) * wind_s);
	amp = w + wood_a * ( texture2D(branch_noise_tex, mv * time * wood_f).rg  * 2.0 - ONE2);
	float xval2 = x_val*x_val;
	
	float fx = 0.374570*xval2 + 0.129428*xval2*xval2;
	float dx = 0.749141*x_val + 0.517713*xval2*x_val;

	vec2 fu			= vec2(fx)		* amp;
	vec2 fu_deriv	= vec2( dx / l) * amp ;
	// restrict fu_deriv != 0.0
	fu_deriv = max(fu_deriv, EPSILONVEC) + min(fu_deriv, EPSILONVEC);
	vec2 us = sqrt(ONE2+fu_deriv*fu_deriv);
	vec2 ud = fu / fu_deriv * (us - ONE2);
	corr_r = (t + r.xy*fu_deriv.x)/us.x * ud.x;
	corr_s = (t + s.xy*fu_deriv.y)/us.y * ud.y;
	// inverse deformation - must be aplyed in oposite direction
	position = position - ( fu.x * r.xy + fu.y * s.xy - (corr_r+corr_s) );
}

vec2 convert2TexCoords(in vec2 sliceCoords){
	return (clamp ( sliceCoords  , vec2(0.0, 0.0), ONE2 ) + sliceDesc) / vec2(sliceCnt,sliceSetsCnt);
}

void	main()
{	

	if (gl_Color.a==0.0){discard;}
	vec4 color = vec4(0.0, 0.0, 0.0, 0.0);
	vec3 cVar;
	vec4 seasonColor = vec4(0.0, 0.0, 0.0, 0.0);
	vec4 normal;
	float leaf = 0.0;
	vec2 newPos;
	float mv_time = (time+time_offset_v) * 0.01;
	// get frag position
	vec2 position = gl_TexCoord[0].st;
	vec2 tpos	= clamp ( position + sliceDesc , sliceDesc, sliceDesc+vec2(1.0, 1.0) ) / vec2(sliceCnt,sliceSetsCnt);
	// get Level-1 branch
	float branchID = (texture2D(dataMap, tpos).r);
	float branchFlag = sign(branchID);
	branchID = abs(branchID);
	float offset = sliceDesc.y*texCols;
	float texCol = 1.0/(sliceSetsCnt*texCols);
	
	// level 1 deformation...
	if (branchID>(0.5)/branch_count){
		animateBranch(position, branchID, mv_time, offset, texCol, wood_amplitudes.y, wood_frequencies.y, v_wind_dir_ts, wind_strength);
	}
	// animate trunk
	animateBranch(position, 0.0, mv_time, offset, texCol, wood_amplitudes.x, wood_frequencies.x, v_wind_dir_ts, wind_strength);
	if (position.y>1.0){
		discard;
	}
	// is it a leaf-fragment? yes -> can animate leaf
	newPos = convert2TexCoords(position);
	bool isLeaf = sign(texture2D(dataMap, newPos).r)>=0.0;
	int front = -1;
	if (gl_FrontFacing){
		front = 1;
	}
	float NdotL;
	if (isLeaf){
		// leaf

		// distort...
		vec2 texCoordA = tpos+leaf_frequency*mv_time*movementVectorA*2.0;
		vec2 texCoordB = tpos+leaf_frequency*mv_time*movementVectorB*2.0;

		vec2 noise = ((texture2D(leaf_noise_tex, texCoordB).st + texture2D(leaf_noise_tex, texCoordA).st) - ONE2);
		vec2 newPosD = convert2TexCoords(position + leaf_amplitude*0.005*noise);
		// is the source fragment from branch? if so use original coords...
		if(sign(texture2D(dataMap, newPosD).r)>=0.0){
			newPos = newPosD;
		}
		color += texture2D(colorMap, newPos);
		if (color.a<ALPHA_TRESHOLD){
			discard;
		}
		normal = texture2D(normalMap, newPos);
		float leaf = (1.0/(1.0-0.004))*(normal.w-0.004);
		vec2 seasonCoord = vec2(0.5, season + 0.2*leaf - 0.0001*time_offset_v);		
		seasonColor = texture2D(seasonMap, seasonCoord);
		if (seasonColor.a<0.5){
			discard;
		}
		cVar = colorVar;
		//normal = vec4(0.0,0.0,1.0, 0.0);
		normal = -front*normal;



	} else {
		//branch
		color += texture2D(colorMap, newPos);
		if (color.a<ALPHA_TRESHOLD){
			discard;
		}
		cVar = vec3(1.0, 1.0, 1.0);
		normal = texture2D(normalMap, newPos);
		//normal = vec4(0.0,0.0,1.0, 0.0);
		normal.z = -front*normal.z;
	}
	NdotL = dot ( normalize ( normal.xyz ) , normalize ( lightDir_ts ));
	// SHADOW MAPPING //
	float shade = 1.0;
	if (shadowMappingEnabled>0){
		float depth_tex = texture2D(depthMap, newPos).x*2.0 - 1.0;
		// offset camera depth
		float offset = depth_tex*0.33333333*(far-near);
		float depthEye   = lightSpacePosition.z-front*offset;
		//vec4(lightSpacePosition.xy, depthEye, 0.0);
		//float depthLight = getDepth( lightSpacePosition.xy );
		shade = getShadowIntensity(vec4(lightSpacePosition.xy, depthEye, 0.0));
	}
	// SHADOW MAPPING END //	
	color.rgb += seasonColor.rgb;
	color.rgb *= cVar;
	vec3 ambient = color.rgb * gl_LightSource[0].ambient.xyz * MultiplyAmbient;
	vec3 diffuse = color.rgb * gl_FrontLightProduct[0].diffuse.xyz * clamp(NdotL, 0.0, 1.0) * MultiplyDiffuse * shade;
	//vec3 specular= ;
	vec3 translucency= color.rgb * clamp(-NdotL, 0.0, 1.0) * 1.5 * MultiplyTranslucency * shade;
	color.rgb = ambient + diffuse + translucency;
	//color.rgb = diffuse;
	
	color.a *= gl_Color.a;
	gl_FragData[0] = color;
	gl_FragData[1] = color * vec4(0.1, 0.1, 0.1, 1.0);

	
	
}


/*
void	main()
{	
	vec3 eyeDir_ts2 = normalize(eyeDir_ts);
	float sizeFactor = 1.5/max(window_size.x, window_size.y);

	float dist = gl_FragCoord.z;
	float inv_dist = 1.0/dist;
	float t			= 10.0*(time+time_offset_v)*leaf_frequency*sizeFactor;
	vec2 movVectorA = movementVectorA;
	vec2 movVectorB = movementVectorB;

	

	vec2 texC		= gl_TexCoord[0].st;
	vec2 fpos		= clamp ( texC + sliceDesc , sliceDesc, sliceDesc+vec2(1.0, 1.0) ) / vec2(sliceCnt,sliceSetsCnt);
	
	vec2 mv1 = texture2D(dataMap, fpos).xy*2.0 - vec2(1.0);
	float mv_time = 0.01 * (time+time_offset_v);
	vec2 amp1 = wood_amplitudes.y * ( texture2D(branch_noise_tex, mv1 * mv_time * wood_frequencies.y).rg  * 2.0 - vec2(1.0));


	vec2 texCoordA	= fpos+t*movVectorA;
	vec2 texCoordB	= fpos+t*movVectorB; // gl_TexCoord[0].st+t*movVectorB;
	
	vec2 oneV2 = vec2(1.0);
	vec2 b0 = vec2(0.5,0.0);
	vec2 b1 = texture2D(dataMap, fpos).zw;

	float dist0 = min (1.0, 2.0 * length(texC - b0)) ; // / branchProjectedLength
	float dist1 = min (1.0, 5.0 * length(texC - b1)); // / branchProjectedLength

	vec4 color;
	float angle;
	float cosA;
	float sinA;
	vec2  difVec;
	mat2 R;
	vec2 rotatedDifVec;
	vec2 newPos = texC;
	float ti = (time+time_offset_v)*sizeFactor*10.0;
	vec2 si = sizeFactor* 100.0 * wood_amplitudes.xy;
	float d = length(b1-vec2(0.5));

	if ((d>0.01)){
		//angle = dist1 * (amp1.x+amp1.y) * sizeFactor * 200;
		angle = dist1*(texture2D(branch_noise_tex, (ti * b1 * wood_frequencies.y)).s*2.0 - 1.0)  * si.y * 2.0;
		//angle = (texture2D(branch_noise_tex, (ti * b1 * wood_frequencies.y)).s*2.0 - 1.0) * si.y;
		
		cosA = cos (angle); 
		sinA = sin (angle);
		difVec = (newPos - b1);
		R = mat2(	 cosA	, sinA,
 					-sinA	, cosA );
		rotatedDifVec = R*difVec;
		newPos = b1 + rotatedDifVec;
	}
	
	angle = dist0 * (texture2D(branch_noise_tex, (ti * b0 * wood_frequencies.x)).s*2.0-1.0) * si.x * 0.5;
	cosA = cos (angle); 
	sinA = sin (angle);
	difVec = (newPos - b0);
	R = mat2(	 cosA	, sinA,
 				-sinA	, cosA );
	rotatedDifVec = R*difVec;
	newPos = b0 + rotatedDifVec;
	
	// bending done...


	newPos = clamp ( newPos  , vec2(0.0, 0.0), vec2(1.0, 1.0) );// + sliceDesc ) / vec2(sliceCnt,sliceSetsCnt);
	newPos = (newPos + sliceDesc) / vec2(sliceCnt,sliceSetsCnt);
	texCoordA = (texture2D(leaf_noise_tex, texCoordA).st*2.0 - vec2(1.0));
	texCoordB = (texture2D(leaf_noise_tex, texCoordB).st*2.0 - vec2(1.0));
	
	//newPos = fpos;
	vec4 fragmentNormal;
	vec2 noiseOffset = (texCoordA+texCoordB)*sizeFactor*leaf_amplitude*0.5 / sliceCnt;
	
	vec2 texCoord = newPos + noiseOffset ;
	vec4 fragmentNormalLeaf = texture2D(normalMap, texCoord);
	vec4 fragmentNormalBranch = texture2D(normalMap, newPos);
	float branchFlag = fragmentNormalBranch.w + fragmentNormalLeaf.w;
	vec2 lookUpPos = newPos;
	float leaf = 1.0;
	if (branchFlag<0.004){
		// trunk / branch 
		leaf = 0.0;
		fragmentNormal = fragmentNormalBranch;
		fragmentNormal.xyz = fragmentNormal.xyz*2.0 - vec3(1.0);
		// pseudo-parallax mapping //
		//float height = fragmentNormal.z;			
		//float hsb = height * scale + bias;    
		//vec2 normalLookUp = newPos + (hsb * eyeDir_ts.xy);
		//
		//fragmentNormal = texture2D( normalMap, normalLookUp );
		//lookUpPos = newPos;
		

	} else {
		// foliage
		fragmentNormal = fragmentNormalLeaf;
		fragmentNormal.xyz = fragmentNormal.xyz*2.0 - vec3(1.0);
		
		lookUpPos = texCoord;
		
		leaf = (1.0/(1.0-0.004))*(fragmentNormal.w-0.004);
		// if normal runs to the negative half-space
		if (fragmentNormal.z<0.0){
			fragmentNormal = -fragmentNormal;
		}
		
	}
	//fragmentNormal = fragmentNormalBranch;
	
	if (gl_FrontFacing){
		fragmentNormal.z = -fragmentNormal.z;
	}
	// float h = gl_FrontMaterial.shininess;
	// vec3 E = -eyeDir_ts2;
	// vec3 Refl = reflect(-lightDir_ts, normalize ( fragmentNormal.xyz ));
	// float RdotE = max(dot(Refl, E),0.0);
	float NdotL = dot ( normalize ( fragmentNormal.xyz ) , normalize ( lightDir_ts ));
	float frontFacing = sign(NdotL);
	NdotL = clamp(NdotL, 0.0, 1.0);
	// float NodotE = clamp ( abs(dot ( vec3(0.0, 0.0, 1.0), eyeDir_ts2 )) , 0.0, 1.0);
	

	//float spec = pow( RdotE, h );
	//vec4 ambient = gl_LightSource[0].ambient;
	//vec4 diffuse = gl_FrontLightProduct[0].diffuse * NdotL * NodotE;
	//vec4 specular = gl_FrontLightProduct[0].specular * spec;
	vec4 decal_color = texture2D(colorMap, lookUpPos);
	
	// escape when transparent...
	if (decal_color.a<0.75){discard;}

	//vec3 translucency_in_light = translucency * other_cpvcolor.rgb * gl_LightSource[0].diffuse.rgb ;
	vec3 final_translucency;// * (shadow_intensity * ReduceTranslucencyInShadow)* MultiplyTranslucency;
	vec4 final_ambient = vec4(0.0);
	vec4 final_diffuse = vec4(0.0);
	//vec3 variation = colorVar;
	float noise1f = 0.0;
	if (leaf>0.0){
		// leaf
		float mNdotL = max ( -dot ( normalize ( fragmentNormal.xyz ) , normalize ( lightDir_ts ) ) , 0.0);
		vec4 noise = texture2D(leaf_noise_tex, vec2(1.0, leaf)*t);
		noise1f = noise.x*2.0-1.0;
		//mNdotL += noise1f;
		NdotL += 0.5*noise1f;
		//leaf-=0.1;
		vec2 seasonCoord = vec2(0.5, season + 0.2*leaf - 0.0001*time_offset_v);
		vec4 seasonColor =  texture2D(seasonMap, seasonCoord);
		if (seasonColor.a<0.5){
			discard;
		}
		decal_color.rgb += seasonColor.rgb;
		decal_color.rgb *= colorVar;
		decal_color.a *= seasonColor.a;
		final_translucency = decal_color.rgb * mNdotL * 0.6 * MultiplyTranslucency;
		final_ambient = decal_color * gl_LightSource[0].ambient * MultiplyAmbient;
		final_diffuse = decal_color * NdotL * gl_FrontLightProduct[0].diffuse * MultiplyDiffuse;
	} 
	else {
		// branch
		//decal_color = vec4(1.0, 0.0, .0, 1.0); // debug
		final_translucency = vec3(0.0, 0.0, 0.0);
		final_ambient = decal_color * gl_LightSource[0].ambient * MultiplyAmbient;
		final_diffuse = decal_color * NdotL * MultiplyDiffuse;
	}
	color.rgb = final_ambient.rgb + final_diffuse.rgb + final_translucency;
	color.a = alpha;

	if (shadowMappingEnabled>0){
		// SHADOW MAPPING //
		float depth_tex = texture2D(depthMap, lookUpPos).x;
		vec4 lpos = (lightSpacePosition/lightSpacePosition.w * 0.5) + vec4(0.5);
		float depthEye   = lpos.z;
		float depthLight = getDepth( lpos.xy );
		float shade = 1.0;
		// offset camera depth
		float remapFactor = 1.0 / (far-near);
		float offset = (depth_tex*2.0 - 1.0)*0.333*remapFactor;

		// perspective
		//offset = ((-2.0*near*far/(offset*(near-far))) + 1.0);

		depthEye += -frontFacing*offset;
		if ((depthEye - depthLight) > SHADOW_TRESHOLD){
			shade = 0.5;
		}
		//color.rgb =vec3 (-frontFacing*offset*0.5 + 0.5); 
		color.rgb *= shade;
		// SHADOW MAPPING END
	}


	// fade LOD
	color.a *= gl_Color.a;
	gl_FragData[0] = color;

	if (leaf>0.0){
		gl_FragData[1] = color * vec4(0.1, 0.1, 0.1, 1.0);
	} else {		
		gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);	
	}	
	//float sig = (1.0-transition_control);
	//gl_FragDepth = gl_FragCoord.z + 0.01*sig*sig;
}

*/