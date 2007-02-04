abstract class A
{	void delegate() on_update = null;

	int x;
	
	void update()
	{	on_update();
	}
}

class B : A
{	int y;

	void doThis()
	{ printf("b\n");}
}

class C : B
{
	int z;

	void doThat()
	{ printf("c\n");}
}

void main()
{
	C c = new C();

	void myFunc()
	{	c.doThis(); // fine
		c.doThat(); // crashes
		c.x = 1;
		c.y = 2;
		c.z = 3;
		printf("%d\n", c.y);
	}
	
	B b = new B();
	b.on_update = &myFunc;
	
	b.update();
}