#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#import "GLESView.h"
#import "vmath.h"

enum
{
    CG_ATTRIBUTE_VERTEX_POSITION = 0,
    CG_ATTRIBUTE_COLOR,
    CG_ATTRIBUTE_NORMAL,
    CG_ATTRIBUTE_TEXTURE0,
};

@implementation GLESView
{
    EAGLContext *context;

    GLuint defaultFramebuffer;
    GLuint colorRenderbuffer;
    GLuint depthRenderbuffer;

    GLuint vertexShaderObject;
    GLuint fragmentShaderObject;
    GLuint shaderProgramObject;

    GLfloat angleCube;
    GLfloat anglePyramid;
    GLfloat speed;

    GLuint vaoPyramid;
    GLuint vboPyramidPosition;
    GLuint vboPyramidColor;
    GLuint vaoCube;
    GLuint vboCubePosition;
    GLuint vboCubeColor;
    GLuint mvpUniform;

    vmath::mat4 perspectiveProjectionMatrix;

    CADisplayLink *displayLink;

    NSInteger aimationFrameInterval;
    NSInteger singleTapCounter;

    BOOL isRendering;
}

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if(self)
    {
        vertexShaderObject = 0;
        fragmentShaderObject = 0;
        shaderProgramObject = 0;

        vaoPyramid = 0;
        vboPyramidPosition = 0;
        vboPyramidColor = 0;
        vaoCube = 0;
        vboCubePosition = 0;
        vboCubeColor = 0;
        mvpUniform = 0;

        angleCube = 0.0f;
        anglePyramid = 0.0f;
        speed = 0.5f;

        if(![self initializeContext])
        {
            // Return nil as this will release 'self'
            return nil;
        }

        isRendering = NO;
        aimationFrameInterval = 60;
        singleTapCounter = 1;

        // Initialize the shaders and shader program object.

        [self initializeGestures];
        [self initializeVertexShader];
        [self initializeFragmentShader];
        [self initializeShaderProgram];
        [self initializePyramidBuffers];
        [self initializeCubeBuffers];

        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);

        glEnable(GL_DEPTH_TEST);

        // Disable face culling to see back side of object when rotated.
        // glEnable(GL_CULL_FACE);

        glDepthFunc(GL_LEQUAL);

        perspectiveProjectionMatrix = vmath::mat4::identity();
    }

    return self;
}

-(BOOL)acceptsFirstResponder
{
    return YES;
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
//    [self setNeedsDisplay];
}

-(void)onSingleTap:(UIGestureRecognizer *)gestureRecognizer
{
    singleTapCounter++;

    if(singleTapCounter < 1 || singleTapCounter > 9) {
        singleTapCounter = 1;
    }

    speed = 0.5f * (float)singleTapCounter;

    [self setNeedsDisplay];
}

-(void)onDoubleTap:(UIGestureRecognizer *)gestureRecognizer
{
    [self setNeedsDisplay];
}

-(void)onLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    [self setNeedsDisplay];
}

-(void)onSwip:(UISwipeGestureRecognizer *)gestureRecognizer
{
    [self release];
    exit(EXIT_SUCCESS);
}

+(Class)layerClass
{
    return [CAEAGLLayer class];
}

-(void)initializeGestures
{
    UITapGestureRecognizer *doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTap:)];
    [doubleTapGestureRecognizer setNumberOfTapsRequired:2];
    [doubleTapGestureRecognizer setNumberOfTouchesRequired:1];
    [doubleTapGestureRecognizer setDelegate:self];
    [self addGestureRecognizer:doubleTapGestureRecognizer];

    UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSingleTap:)];
    [singleTapGestureRecognizer setNumberOfTapsRequired:1];
    [singleTapGestureRecognizer setNumberOfTouchesRequired:1];
    [singleTapGestureRecognizer setDelegate:self];
    [singleTapGestureRecognizer requireGestureRecognizerToFail:doubleTapGestureRecognizer];
    [self addGestureRecognizer:singleTapGestureRecognizer];

    UILongPressGestureRecognizer *longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
    [self addGestureRecognizer:longPressGestureRecognizer];

    UISwipeGestureRecognizer *swipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(onSwip:)];
    [self addGestureRecognizer:swipeGestureRecognizer];
}

-(BOOL)initializeContext
{
    NSMutableDictionary *drawableProperties = [[NSMutableDictionary alloc] init];
    [drawableProperties setObject:[NSNumber numberWithBool:NO] forKey:kEAGLDrawablePropertyRetainedBacking];
    [drawableProperties setObject:kEAGLColorFormatRGBA8 forKey:kEAGLDrawablePropertyColorFormat];

    CAEAGLLayer *layer = (CAEAGLLayer *)super.layer;
    layer.opaque = NO;
    layer.drawableProperties = drawableProperties;

    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];

    [drawableProperties release];
    drawableProperties = nil;

    if(context == nil)
    {
        NSLog(@"[Error] | Cannot create OpenGL ES 3.0 context");
        [self release];
        return NO;
    }

    [EAGLContext setCurrentContext:context];

    glGenFramebuffers(1, &defaultFramebuffer);
    glGenRenderbuffers(1, &colorRenderbuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);

    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);

    GLint backingWidth = 0;
    GLint backingHeight = 0;

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);

    glGenRenderbuffers(1, &depthRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, backingWidth, backingHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);

    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"[Error] | Cannot create complete framebuffer object, status: %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        glDeleteFramebuffers(1, &defaultFramebuffer);
        glDeleteRenderbuffers(1, &colorRenderbuffer);
        glDeleteRenderbuffers(1, &depthRenderbuffer);

        return NO;
    }

    NSLog(@"[Info] | Renderer: %s", glGetString(GL_RENDERER));
    NSLog(@"[Info] | OpenGL ES version: %s", glGetString(GL_VERSION));
    NSLog(@"[Info] | GLSL version: %s", glGetString(GL_SHADING_LANGUAGE_VERSION));

    return YES;
}

-(void)listExtensions
{
    GLint extensionCount = 0;
    glGetIntegerv(GL_NUM_EXTENSIONS, &extensionCount);

    NSLog(@"Number of extensions: %d\n", extensionCount);

    for(int counter = 0; counter < extensionCount; ++counter)
    {
        NSLog(@"%d] Extension name: %s\n", counter + 1, (const char*)glGetStringi(GL_EXTENSIONS, counter));
    }
}

-(void)initializeVertexShader
{
    vertexShaderObject = glCreateShader(GL_VERTEX_SHADER);

    const GLchar *vertexShaderCode = "#version 300 es" \
    "\n" \
    "in vec4 vertexPosition;" \
    "in vec4 vertexColor;" \
    "\n" \
    "out vec4 outVertexColor;" \
    "\n" \
    "uniform mat4 mvpMatrix;" \
    "\n" \
    "void main(void)" \
    "{" \
    "   gl_Position = mvpMatrix * vertexPosition;" \
    "   outVertexColor = vertexColor;" \
    "}";

    glShaderSource(vertexShaderObject, 1, (const GLchar**)&vertexShaderCode, NULL);
    glCompileShader(vertexShaderObject);

    GLint infoLogLength = 0;
    GLint shaderCompileStatus = 0;
    char *infoLog = NULL;

    glGetShaderiv(vertexShaderObject, GL_COMPILE_STATUS, &shaderCompileStatus);

    if(shaderCompileStatus == GL_FALSE)
    {
        glGetShaderiv(vertexShaderObject, GL_INFO_LOG_LENGTH, &infoLogLength);

        if(infoLogLength > 0)
        {
            infoLog = (char *)malloc(infoLogLength);

            if(infoLog != NULL)
            {
                GLsizei written = 0;
                glGetShaderInfoLog(vertexShaderObject, infoLogLength, &written, infoLog);
                NSLog(@"CG: Vertex shader compilation log: %s\n", infoLog);
                free(infoLog);
                [self release];
                exit(EXIT_FAILURE);
            }
        }
    }
}

-(void)initializeFragmentShader
{
    fragmentShaderObject = glCreateShader(GL_FRAGMENT_SHADER);

    const GLchar *fragmentShaderCode = "#version 300 es" \
    "\n" \
    "precision highp float;"\
    "in vec4 outVertexColor;" \
    "\n" \
    "out vec4 fragmentColor;" \
    "\n" \
    "void main(void)" \
    "{" \
    "   fragmentColor = outVertexColor;" \
    "}";

    glShaderSource(fragmentShaderObject, 1, (const GLchar**)&fragmentShaderCode, NULL);
    glCompileShader(fragmentShaderObject);

    GLint infoLogLength = 0;
    GLint shaderCompileStatus = 0;
    char *infoLog = NULL;

    glGetShaderiv(fragmentShaderObject, GL_COMPILE_STATUS, &shaderCompileStatus);

    if(shaderCompileStatus == GL_FALSE)
    {
        glGetShaderiv(fragmentShaderObject, GL_INFO_LOG_LENGTH, &infoLogLength);

        if(infoLogLength > 0)
        {
            infoLog = (char *)malloc(infoLogLength);

            if(infoLog != NULL)
            {
                GLsizei written = 0;
                glGetShaderInfoLog(fragmentShaderObject, infoLogLength, &written, infoLog);
                NSLog(@"CG: Fragment shader compilation log: %s\n", infoLog);
                free(infoLog);
                [self release];
                exit(EXIT_FAILURE);
            }
        }
    }
}

-(void)initializeShaderProgram
{
    shaderProgramObject = glCreateProgram();

    glAttachShader(shaderProgramObject, vertexShaderObject);
    glAttachShader(shaderProgramObject, fragmentShaderObject);

    // Bind the position attribute location before linking.
    glBindAttribLocation(shaderProgramObject, CG_ATTRIBUTE_VERTEX_POSITION, "vertexPosition");

    // Bind the color attribute location before linking.
    glBindAttribLocation(shaderProgramObject, CG_ATTRIBUTE_COLOR, "vertexColor");

    // Now link and check for error.
    glLinkProgram(shaderProgramObject);

    GLint infoLogLength = 0;
    GLint shaderProgramLinkStatus = 0;
    char *infoLog = NULL;

    glGetProgramiv(shaderProgramObject, GL_LINK_STATUS, &shaderProgramLinkStatus);

    if(shaderProgramLinkStatus == GL_FALSE)
    {
        glGetProgramiv(shaderProgramObject, GL_INFO_LOG_LENGTH, &infoLogLength);

        if(infoLogLength > 0)
        {
            infoLog = (char *)malloc(infoLogLength);

            if(infoLog != NULL)
            {
                GLsizei written = 0;
                glGetProgramInfoLog(shaderProgramObject, infoLogLength, &written, infoLog);
                NSLog(@"CG: Shader program link log: %s\n", infoLog);
                free(infoLog);
                [self release];
                exit(EXIT_FAILURE);
            }
        }
    }

    // After linking get the value of MVP uniform location from the shader program.
    mvpUniform = glGetUniformLocation(shaderProgramObject, "mvpMatrix");
}

-(void)initializePyramidBuffers
{
    const GLfloat pyramidVertices[] = {
        // Front face
        0.0f, 1.0f, 0.0f,
        -1.0f, -1.0f, 1.0f,
        1.0f, -1.0f, 1.0f,

        // Right face
        0.0f, 1.0f, 0.0f,
        1.0f, -1.0f, 1.0f,
        1.0f, -1.0f, -1.0f,

        // Back face
        0.0f, 1.0f, 0.0f,
        1.0f, -1.0f, -1.0f,
        -1.0f, -1.0f, -1.0f,

        // Left face
        0.0f, 1.0f, 0.0f,
        -1.0f, -1.0f, -1.0f,
        -1.0f, -1.0f, 1.0f
    };

    const GLfloat pyramidColors[] = {
        // Front face
        1.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 1.0f,

        // Right face
        1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 1.0f, 0.0f,

        // Back face
        1.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 1.0f,

        // Left face
        1.0f, 0.0f, 0.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 1.0f, 0.0f
    };

    glGenVertexArrays(1, &vaoPyramid);
    glBindVertexArray(vaoPyramid);

    glGenBuffers(1, &vboPyramidPosition);
    glBindBuffer(GL_ARRAY_BUFFER, vboPyramidPosition);

    glBufferData(GL_ARRAY_BUFFER, sizeof(pyramidVertices), pyramidVertices, GL_STATIC_DRAW);
    glVertexAttribPointer(CG_ATTRIBUTE_VERTEX_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(CG_ATTRIBUTE_VERTEX_POSITION);

    glBindBuffer(GL_ARRAY_BUFFER, 0);

    glGenBuffers(1, &vboPyramidColor);
    glBindBuffer(GL_ARRAY_BUFFER, vboPyramidColor);

    glBufferData(GL_ARRAY_BUFFER, sizeof(pyramidColors), pyramidColors, GL_STATIC_DRAW);
    glVertexAttribPointer(CG_ATTRIBUTE_COLOR, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(CG_ATTRIBUTE_COLOR);

    glBindBuffer(GL_ARRAY_BUFFER, 0);

    glBindVertexArray(0);
}

-(void)initializeCubeBuffers
{
    const GLfloat cubeVertices[] = {
        // Top face
        1.0f, 1.0f, -1.0f,
        -1.0f, 1.0f, -1.0f,
        -1.0f, 1.0f, 1.0f,
        1.0f, 1.0f, 1.0f,

        // Bottom face
        1.0f, -1.0f, -1.0f,
        -1.0f, -1.0f, -1.0f,
        -1.0f, -1.0f, 1.0f,
        1.0f, -1.0f, 1.0f,

        // Front face
        1.0f, 1.0f, 1.0f,
        -1.0f, 1.0f, 1.0f,
        -1.0f, -1.0f, 1.0f,
        1.0f, -1.0f, 1.0f,

        // Back face
        1.0f, 1.0f, -1.0f,
        -1.0f, 1.0f, -1.0f,
        -1.0f, -1.0f, -1.0f,
        1.0f, -1.0f, -1.0f,

        // Right face
        1.0f, 1.0f, -1.0f,
        1.0f, 1.0f, 1.0f,
        1.0f, -1.0f, 1.0f,
        1.0f, -1.0f, -1.0f,

        // Left face
        -1.0f, 1.0f, 1.0f,
        -1.0f, 1.0f, -1.0f,
        -1.0f, -1.0f, -1.0f,
        -1.0f, -1.0f, 1.0f
    };

    const GLfloat cubeColors[] = {
        // Top face
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,

        // Bottom face
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,

        // Front face
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,

        // Back face
        0.0f, 1.0f, 1.0f,
        0.0f, 1.0f, 1.0f,
        0.0f, 1.0f, 1.0f,
        0.0f, 1.0f, 1.0f,

        // right face
        1.0f, 0.0f, 1.0f,
        1.0f, 0.0f, 1.0f,
        1.0f, 0.0f, 1.0f,
        1.0f, 0.0f, 1.0f,

        // left face
        1.0f, 1.0f, 0.0f,
        1.0f, 1.0f, 0.0f,
        1.0f, 1.0f, 0.0f,
        1.0f, 1.0f, 0.0f
    };

    glGenVertexArrays(1, &vaoCube);
    glBindVertexArray(vaoCube);

    glGenBuffers(1, &vboCubePosition);
    glBindBuffer(GL_ARRAY_BUFFER, vboCubePosition);

    glBufferData(GL_ARRAY_BUFFER, sizeof(cubeVertices), cubeVertices, GL_STATIC_DRAW);
    glVertexAttribPointer(CG_ATTRIBUTE_VERTEX_POSITION, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(CG_ATTRIBUTE_VERTEX_POSITION);

    glBindBuffer(GL_ARRAY_BUFFER, 0);

    glGenBuffers(1, &vboCubeColor);
    glBindBuffer(GL_ARRAY_BUFFER, vboCubeColor);

    glBufferData(GL_ARRAY_BUFFER, sizeof(cubeColors), cubeColors, GL_STATIC_DRAW);
    glVertexAttribPointer(CG_ATTRIBUTE_COLOR, 3, GL_FLOAT, GL_FALSE, 0, NULL);
    glEnableVertexAttribArray(CG_ATTRIBUTE_COLOR);

    glBindBuffer(GL_ARRAY_BUFFER, 0);

    glBindVertexArray(0);
}

-(void)updateScene
{
    angleCube -= speed;
    anglePyramid += speed;

    if(angleCube <= -360.0f)
    {
        angleCube = 0.0f;
    }

    if(anglePyramid >= 360.0f)
    {
        anglePyramid = 0.0f;
    }
}

-(void)render:(id)sender
{
    [EAGLContext setCurrentContext:context];

    glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

    glUseProgram(shaderProgramObject);

    [self drawPyramid];
    [self drawCube];

    glUseProgram(0);

    [context presentRenderbuffer:GL_RENDERBUFFER];

    [self updateScene];
}

-(void)drawPyramid
{
    vmath::mat4 modelViewMatrix = vmath::mat4::identity();
    vmath::mat4 rotationMatrix = vmath::mat4::identity();
    vmath::mat4 modelViewProjectionMatrix = vmath::mat4::identity();

    // Translate the modal view matrix.
    modelViewMatrix = vmath::translate(-1.5f, 0.0f, -6.0f);
    rotationMatrix = vmath::rotate(anglePyramid, 0.0f, 1.0f, 0.0f);

    // Rotate after transformation of modelViewMatrix.
    modelViewMatrix = modelViewMatrix * rotationMatrix;

    // Multiply modelViewMatrix and perspectiveProjectionMatrix to get modelViewProjectionMatrix
    // Oder of multiplication is very important projectionMatrix * modelMatrix * viewMatrix
    // As we have model and view matrix combined, we just have to multiply projectionMatrix and modelViewMatrix
    modelViewProjectionMatrix = perspectiveProjectionMatrix * modelViewMatrix;

    // Pass modelViewProjectionMatrix to vertex shader in 'mvpMatrix' variable defined in shader.
    glUniformMatrix4fv(mvpUniform, 1, GL_FALSE, modelViewProjectionMatrix);

    // Now bind the VAO to which we want to use
    glBindVertexArray(vaoPyramid);

    // Draw the pyramid
    // 12 is number of vertices in the array i.e. element count in pyramidVertices divide by 3 (x, y, z) component
    glDrawArrays(GL_TRIANGLES, 0, 12);

    // unbind the vao
    glBindVertexArray(0);
}

-(void)drawCube
{
    vmath::mat4 modelViewMatrix = vmath::mat4::identity();
    vmath::mat4 rotationMatrix = vmath::mat4::identity();
    vmath::mat4 scaleMatrix = vmath::mat4::identity();
    vmath::mat4 modelViewProjectionMatrix = vmath::mat4::identity();

    // Scale, translate and rotate the modal view matrix.
    scaleMatrix = vmath::scale(0.75f, 0.75f, 0.75f);
    modelViewMatrix = vmath::translate(1.5f, 0.0f, -6.0f);
    rotationMatrix = vmath::rotate(angleCube, angleCube, angleCube);

    // Scale after transformation of modelViewMatrix.
    modelViewMatrix = modelViewMatrix * scaleMatrix;

    // Rotate after transformation and scale of modelViewMatrix.
    modelViewMatrix = modelViewMatrix * rotationMatrix;

    // Multiply modelViewMatrix and perspectiveProjectionMatrix to get modelViewProjectionMatrix
    // Oder of multiplication is very important projectionMatrix * modelMatrix * viewMatrix
    // As we have model and view matrix combined, we just have to multiply projectionMatrix and modelViewMatrix
    modelViewProjectionMatrix = perspectiveProjectionMatrix * modelViewMatrix;

    // Pass modelViewProjectionMatrix to vertex shader in 'mvpMatrix' variable defined in shader.
    glUniformMatrix4fv(mvpUniform, 1, GL_FALSE, modelViewProjectionMatrix);

    // Now bind the VAO to which we want to use
    glBindVertexArray(vaoCube);

    // Draw the cube
    // 4 is number of vertices in the array for each face
    // i.e. element count in cubeVertices for each face divide by 3 (x, y, z) component
    // 2nd parameter is the index from which we need to use vertices.
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 4, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 8, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 12, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 16, 4);
    glDrawArrays(GL_TRIANGLE_FAN, 20, 4);

    // unbind the vao
    glBindVertexArray(0);
}

-(void)layoutSubviews
{
    GLint width = 0;
    GLint height = 0;

    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);

    glGenRenderbuffers(1, &depthRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);

    if(height == 0)
    {
        height = 1;
    }

    glViewport(0, 0, width, height);
    perspectiveProjectionMatrix = vmath::perspective(45.0f, (GLfloat)width / (GLfloat)height, 1.0f, 100.0f);

    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"[Error] | Cannot create complete framebuffer object, status: %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
    }

    [self render: nil];
}

-(void)startRendering
{
    if(!isRendering)
    {
        Class displayLinkClass = NSClassFromString(@"CADisplayLink");

        displayLink = [displayLinkClass displayLinkWithTarget:self selector:@selector(render:)];
        [displayLink setPreferredFramesPerSecond:aimationFrameInterval];
        [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];

        isRendering = YES;
    }
}

-(void)stopRendering
{
    if(isRendering)
    {
        [displayLink invalidate];
        displayLink = nil;

        isRendering = NO;
    }
}

-(void)dealloc
{
    [self stopRendering];

    if(vaoPyramid)
    {
        glDeleteVertexArrays(1, &vaoPyramid);
        vaoPyramid = 0;
    }

    if(vboPyramidPosition)
    {
        glDeleteBuffers(1, &vboPyramidPosition);
        vboPyramidPosition = 0;
    }

    if(vboPyramidColor)
    {
        glDeleteBuffers(1, &vboPyramidColor);
        vboPyramidColor = 0;
    }

    if(vaoCube)
    {
        glDeleteVertexArrays(1, &vaoCube);
        vaoCube = 0;
    }

    if(vboCubePosition)
    {
        glDeleteBuffers(1, &vboCubePosition);
        vboCubePosition = 0;
    }

    if(vboCubeColor)
    {
        glDeleteBuffers(1, &vboCubeColor);
        vboCubeColor = 0;
    }

    if(shaderProgramObject)
    {
        if(vertexShaderObject)
        {
            glDetachShader(shaderProgramObject, vertexShaderObject);
        }

        if(fragmentShaderObject)
        {
            glDetachShader(shaderProgramObject, fragmentShaderObject);
        }
    }

    if(vertexShaderObject)
    {
        glDeleteShader(vertexShaderObject);
        vertexShaderObject = 0;
    }

    if(fragmentShaderObject)
    {
        glDeleteShader(fragmentShaderObject);
        fragmentShaderObject = 0;
    }

    if(shaderProgramObject)
    {
        glDeleteProgram(shaderProgramObject);
        shaderProgramObject = 0;
    }

    glUseProgram(0);

    if(depthRenderbuffer)
    {
        glDeleteRenderbuffers(1, &depthRenderbuffer);
        depthRenderbuffer = 0;
    }

    if(colorRenderbuffer)
    {
        glDeleteRenderbuffers(1, &colorRenderbuffer);
        colorRenderbuffer = 0;
    }

    if(defaultFramebuffer)
    {
        glDeleteFramebuffers(1, &defaultFramebuffer);
        defaultFramebuffer = 0;
    }

    if([EAGLContext currentContext] == context)
    {
        [EAGLContext setCurrentContext:nil];
    }

    [context release];
    context = nil;

    [super dealloc];
}

@end
