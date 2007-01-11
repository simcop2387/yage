			// Simply the assignment of uniform values to the lights
			void putLightAttribv(int index, char[] name, float[] value)
			{	char[256] string = 0;
				std.c.stdio.sprintf(string, "lights[%d].%.*s", index, name);
				int location = glGetUniformLocationARB(program, string);
				if (location != -1)
				{	if (value.length == 1) glUniform1fvARB(location, 1, value);
					if (value.length == 3) glUniform3fvARB(location, 1, value);
					if (value.length == 4) glUniform4fvARB(location, 1, value);
				}
				else
					writefln(.toString(string), ' ', value);
			}
			void putLightAttrib(int index, char[] name, float value)
			{	float[1] t = value;
				putLightAttribv(index, name, t);
			}


			// Send each of the lights in uniform variables
			// It seems that all uniform variables are assigned the values of the first pass.
			for (int i=0; i<lights.length; i++)
			{
				Matrix cam_trans = Device.getCurrentCamera().getAbsoluteTransform();
				Vec3f light_pos = lights[i].getAbsolutePosition().rotate(cam_trans.inverse());
				Vec3f cam_pos = (Vec3f(cam_trans.v[12..15])).rotate(cam_trans.inverse());

				putLightAttribv(i, "ambient",				lights[i].getAmbient().v);
				putLightAttribv(i, "diffuse",				lights[i].getDiffuse().v);
				putLightAttribv(i, "specular",				lights[i].getSpecular().v);
				putLightAttribv(i, "position",				(light_pos - cam_pos).v ~ 1.0f);	// 1.0 for point, memory leak!
				putLightAttribv(i, "halfVector",			lights[i].getDiffuse().v);
				putLightAttribv(i, "spotDirection",			lights[i].getDiffuse().v);
				putLightAttrib(i, "spotExponent",			lights[i].getSpotExponent());
				putLightAttrib(i, "spotCutoff",				lights[i].getLightType() == LIGHT_SPOT ? lights[i].getSpotAngle()*_180_PI : 180.0f);
				putLightAttrib(i, "spotCosCutoff",			cos(lights[i].getSpotAngle()*_180_PI));
				putLightAttrib(i, "constantAttenuation",	0);
				putLightAttrib(i, "linearAttenuation",		0);
				putLightAttrib(i, "quadraticAttenuation",	lights[i].getQuadraticAttenuation());
			}