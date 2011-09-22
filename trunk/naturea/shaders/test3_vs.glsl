#version 120

attribute vec3			normal;
attribute vec3			tangent;
attribute vec2			texCoords0;
attribute vec2			sliceDescription;
varying vec3			eyeDir;
varying vec3			normalDir;
varying float			alpha;
varying vec2			sliceDesc;
uniform int				instancing;
attribute mat4			transformMatrix;

void main()
{
	vec4 pos;
	if (instancing>0){
		// drawing instances
		pos = gl_ModelViewMatrix * transformMatrix * ( gl_Vertex * vec4(10.0, 10.0, 10.0, 1.0));	
		mat3 T = mat3(transformMatrix);

		normalDir = (gl_NormalMatrix * T * normal);
	} else {
		// drawing single geometry
		pos = gl_ModelViewMatrix * ( gl_Vertex * vec4(10.0, 10.0, 10.0, 1.0));
		
		normalDir = (gl_NormalMatrix * normal);
	}
	gl_Position = gl_ProjectionMatrix * pos;
	eyeDir = pos.xyz;
	sliceDesc = sliceDescription;
	gl_TexCoord[0] = vec4(texCoords0, 0.0, 0.0);

	//alpha =clamp(-0.5 + 2.0*abs(dot(normalize(normalDir), normalize(eyeDir))), 0.0, gl_Color.a);
	//alpha = clamp(abs(dot(normalize(normalDir), normalize(eyeDir))), gl_Color.a, 1.0);
	//alpha = gl_Color.a;
	//gl_FrontColor = vec4(normal, alpha);
	
	gl_FrontColor = gl_Color;
}

