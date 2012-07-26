/**
 * Principles:
 * Low level, but higher than OpenGL.
 * Doesn't handle window creation or opengl contexts, just renders to the current.
 * A data structure for each openGL construct:  Texture, ShaderProgram, FrameBuffer, RenderBuffer, etc.
 * No opengl calls in data structures like VertexBuffer or Texture.  This allows any part of them to be used from any thread.
 * Uploads/compiles data structures on first use.
 * Binds to OpenGL without using derelict, so it's lighter weight and easier to track which extensions are used.
 * Uses extensions instead of default opengl functionality for windows compatibility (is this still required?)
 * Uses exceptions for error handling.  If an exception occurs, all state changes are reverted (is this practical?)
 * Data structures have a unique, incrementing id that goes through a lookup table to a data structure holding their opengl id and a boolean to show whether they should be destroyed in opengl.
 *    Their destructors can trigger this destruction in OpenGL.  There could be a GPU.cleanup function that handles this.
 *    A freelist is used to maintain free id's so that the memory always stays compact with no need for relocation.
 * No concept of lights or deprecated opengl concepts.  Pixel shader 3 is epxected.
 *
 * gpu.d // binding and rendering functions
 * capabilities.d
 * data/ folder for all data structures
 */