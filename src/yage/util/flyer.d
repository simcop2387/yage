/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.util.flyer;

import yage.core.all;
import yage.node.all;

///
class Flyer
{

	Node base;
	Node pivot;
	float ldamp, xdamp, ydamp;


	this(BaseNode parent)
	{	base = new Node(parent);
		pivot = new Node(base);
		ldamp = 1;
		xdamp = ydamp = 1;
	}

	void setBase(Node base)
	{	base = this.base;
	}

	Node getBase()
	{	return base;
	}

	Node getPivot()
	{	return pivot;
	}

	void setParent(Node parent)
	{	base.setParent(parent);
	}

	void accelerate(Vec3f acc)
	{	accelerate(acc.x, acc.y, acc.z);
	}

	void accelerate(float x, float y, float z)
	{	Vec3f acc = Vec3f(x, y, z).rotate(pivot.getTransform()).rotate(base.getTransform());
		base.accelerate(acc);
	}

	void angularAccelerate(float x, float y)
	{	base.angularAccelerate(0, x, 0);
		pivot.angularAccelerate(y, 0, 0);
	}

	void setPosition(Vec3f pos)
	{	base.setPosition(pos);
	}

	void setPosition(float x, float y, float z)
	{	base.setPosition(x, y, z);
	}

	void setRotation(float x, float y)
	{	base.setRotation(0, x, 0);
		pivot.setRotation(y, 0, 0);
	}

	void setDampening(float percent)
	{	ldamp = percent;
	}

	void setAngularDampening(float xpercent, float ypercent)
	{	xdamp = xpercent;
		ydamp = ypercent;
	}

	/// Apply dampening to the FloatingCamera.
	void update(float delta)
	{	base.setVelocity(base.getVelocity().scale(maxf(1-delta*ldamp, 0.0f)));
		pivot.setAngularVelocity(pivot.getAngularVelocity().scale(maxf(1-delta*xdamp, 0.0f)));
		base.setAngularVelocity(base.getAngularVelocity().scale(maxf(1-delta*ydamp, 0.0f)));
	}

}
