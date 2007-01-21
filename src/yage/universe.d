module yage.universe;

import std.math;
import std.random;
import std.stdio;
import yage.core.horde;
import yage.core.misc;
import yage.core.vector;
import yage.resource.resource;
import yage.resource.model;
import yage.node.basenode;
import yage.node.node;
import yage.node.model;
import yage.node.scene;

int step = 32;

class GameObject : Node
{
	float mass;
	int type = 0;

	this (Universe scene)
	{	super(scene);
		ModelNode rock = new ModelNode(this);
		rock.setModel(Resource.model("space/asteroid1.ms3d"));
	}

	float getRadius()
	{	return pow(mass, .3333)*.75*4;
	}

	void setMass(float mass)
	{	this.mass = mass;
		children[0].setScale(pow(mass, .33333)/2);
	}

}

class Universe : Scene
{
	void generate(int number, float radius)
	{
		for (int i=0; i<number; i++)
		{
			float dist = random(0, radius)+radius/10;
			float angle = random(0, 2*3.1415);
			float height = random(-radius, radius)*random(0, 1)*random(0, 1)/16;
			Vec3f position = Vec3f(sin(angle)*dist, height, cos(angle)*dist);

			GameObject ast = new GameObject(this);
			ast.setPosition(position);
			ast.setVisible(true);
			ast.setMass(random(1, 3));
			ast.setAngularVelocity(random(-.1, .1), random(-.1, .1), random(-.1, .1));
		}
	}

	void applyForces(GameObject a, GameObject b)
	{
		Vec3f dist;
		dist.v[0..3] = a.getTransformPtr().v[12..15];
		Vec3f temp;
		temp.v[0..3] = b.getTransformPtr().v[12..15];
		dist.x -= temp.x;
		dist.y -= temp.y;
		dist.z -= temp.z;

		float d = dist.x*dist.x + dist.y*dist.y + dist.z*dist.z;
		float force = step*8/d; // 1 should be G.

		float af = force*a.mass;
		float bf = force*b.mass;

		d = 1/sqrt(d);
		dist.x *= d;
		dist.y *= d;
		dist.z *= d;

		Vec3f *a1 = a.getVelocityPtr();
		a1.x += -dist.x*bf;
		a1.y += -dist.y*bf;
		a1.z += -dist.z*bf;

		Vec3f *b1 = b.getVelocityPtr();
		b1.x += dist.x*af;
		b1.y += dist.y*af;
		b1.z += dist.z*af;
	}

	bool checkCollision(Node a, Node b)
	{	Vec3f a1;
		a1.v[0..3] = a.getTransformPtr().v[12..15];
		Vec3f b1;
		b1.v[0..3] = b.getTransformPtr().v[12..15];
		a1.x -= b1.x;
		a1.y -= b1.y;
		a1.z -= b1.z;

		float dist = a1.x*a1.x + a1.y*a1.y + a1.z*a1.z;
		float radius = a.getRadius()+b.getRadius();
		return dist < radius*radius;
	}

	void join(Node a, Node b)
	{
		if (a.getType() != "yage.universe.GameObject" || b.getType() != "yage.universe.GameObject")
			return;

		GameObject c = cast(GameObject)a;
		GameObject d = cast(GameObject)b;

		Vec3f pos = (c.getPosition()*c.mass + d.getPosition()*d.mass) / (c.mass+d.mass);
		Vec3f rot = (c.getRotation()*c.mass + d.getRotation()*d.mass) / (c.mass+d.mass);
		Vec3f vel = (c.getVelocity()*c.mass + d.getVelocity()*d.mass) / (c.mass+d.mass);
		Vec3f ang = (c.getAngularVelocity()*c.mass + d.getAngularVelocity()*d.mass) / (c.mass+d.mass);
		float mass = c.mass+d.mass;

		c.remove();
		d.remove();
		GameObject e = new GameObject(this);
		e.setPosition(pos);
		e.setPosition(rot);
		e.setVelocity(vel);
		e.setAngularVelocity(ang);
		e.setMass(mass);

	}

	void update(float delta)
	{
		// Apply forces to all first-level children that are GameObjects,
		// splitting the work between update frames
		static int q = 0;
		q++;
		if (q==step)
			q = 0;
		for (int i=0; i<children.length; i++)
		{	if (i%step==q)
				if (children[i].getType() == "yage.universe.GameObject")
					for (int j=i+1; j<children.length; j++)
						if (children[j].getType() == "yage.universe.GameObject")
							applyForces(cast(GameObject)children[j], cast(GameObject)children[i]);
		}


		// Sort every object by its x position
		children.sortType!(float).radix( (Node v) { return v.getPosition().x; }, true, true);
		for (int i=0; i<children.length; i++)
			children[i].index = i;	// and update each index

		// Check nodes for collisions with their x-axis neighbors
		for (int i=0; i<children.length; i++)
		{
			float x = children[i].getPosition().x;
			float r = children[i].getRadius();

			// Check Nodes to the left of this Node.
			// While there are Nodes to the left and the distance is less than this Node's radius
			for (int j=i-1; j>0 && r > abs(x-children[j].getPosition().x); j--)
			{	if (checkCollision(children[i], children[j]))
				{	join(children[i], children[j]);
					break;
			}	}

			// Check Nodes to the right of this Node
			for (int j=i+1; j<children.length && r > abs(children[j].getPosition().x-x); j++)
			{	if (checkCollision(children[i], children[j]))
				{	join(children[i], children[j]);
					break;
			}	}
		}

		// Normal update
		super.update(delta);
	}




}
