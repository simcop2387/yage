import std.string;
import std.regexp;
import xmld.xml;
//import console;

import std.c.stdio;
import std.stream;

version = WriteTest;
//version = ReadTest;

void main()
{
    XmlNode node;

    version (WriteTest)
    {
        //Console.io.writeLine("...Writing to blah.xml...");

        node = new XmlNode("blah");
        node.addChild(newNode("mynode")
                        .setAttribute("x", "50")
                        .setAttribute("y", 42)
                        .setAttribute("label", "bob")
                        .addChild(
                            newNode("foobar")
                                .setAttribute("thingie", "weefun")
                                .addCdata("This is character <data>!")
                                .addChild(newNode("baz"))
                                .addChild(
                                    newNode("man")
                                        .setAttribute("does", "this")
                                        .addCdata("ever rock")
                                    )
                            )
                        );
        //node.write(Console.io);

        File f = new File();
        f.create("blah.xml");
        node.write(f);
        f.close();
        delete f;
       // Console.io.writeLine("");
    }
/*
    version (ReadTest)
    {
        Console.io.writeLine("...Reading blah.xml...");
        try
        {
            node = readDocument(new File("blah.xml", FileMode.In));
            node.write(Console.io);
            Console.io.writeLine("");
        }
        catch (Error)
        {
            Console.io.writeLine("Unable to read blah.xml");
        }
    }
    */
}