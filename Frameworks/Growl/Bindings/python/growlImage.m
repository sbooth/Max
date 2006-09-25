/*
 * Copyright 2004 Mark Rowe <bdash@users.sourceforge.net>
 * Released under the BSD license.
 */

#include "Python.h"
#import <Cocoa/Cocoa.h>

typedef struct
{
  PyObject_HEAD
  NSImage *theImage;
} ImageObject;


static PyTypeObject ImageObject_Type;

#define ImageObject_Check(v)  ((v)->ob_type == &ImageObject_Type)

static ImageObject *
newImageObject(NSImage *img)
{
    ImageObject *self;
    if (! img)
    {
        PyErr_SetString(PyExc_TypeError, "Invalid image.");
        return NULL;
    }
        
    self = PyObject_New(ImageObject, &ImageObject_Type);
    if (! self)
        return NULL;
    
    self->theImage = [img retain];
    return self;
}

static void
ImageObject_dealloc(ImageObject *self)
{
    PyObject_Del(self);
}

static PyObject *
ImageObject_getAttr(PyObject *self, PyObject *attr)
{
    char *theAttr = PyString_AsString(attr);
    NSAutoreleasePool *pool = nil;
    
    if (strcmp(theAttr, "rawImageData") == 0)
    {
        pool = [[NSAutoreleasePool alloc] init];
        NSData *imageData = [((ImageObject *) self)->theImage TIFFRepresentation];
        PyObject *pyImageData = PyString_FromStringAndSize([imageData bytes], [imageData length]);
        [pool release];
        return pyImageData;
    }
    else
        return PyObject_GenericGetAttr(self, attr);
}


static PyObject *
ImageObject_imageFromPath(PyTypeObject *cls, PyObject *args)
{
    ImageObject *self;
    char *fileName_ = NULL;
    NSString *fileName = nil;
    NSImage *theImage = nil;
    NSAutoreleasePool *pool = nil;
    
    if (! PyArg_ParseTuple(args, "et:imageFromPath",
                           Py_FileSystemDefaultEncoding, &fileName_))
        return NULL;
        
    pool = [[NSAutoreleasePool alloc] init];
    
    fileName = [NSString stringWithUTF8String:fileName_];
    theImage = [[[NSImage alloc] initWithContentsOfFile:fileName] autorelease];
    self = newImageObject(theImage);
    
    [pool release];
    return (PyObject *) self;
}

static PyObject *
ImageObject_imageWithData(PyTypeObject *cls, PyObject *args)
{
    ImageObject *self;
    char *imageData = NULL;
    int imageDataSize = 0;
    NSImage *theImage = nil;
    NSAutoreleasePool *pool = nil;
    
    if (! PyArg_ParseTuple(args, "s#:imageWithData",
                           &imageData, &imageDataSize))
        return NULL;
        
    pool = [[NSAutoreleasePool alloc] init];
    

    theImage = [[[NSImage alloc] initWithData:[NSData dataWithBytes:imageData
                                                             length:imageDataSize]] autorelease];
    self = newImageObject(theImage);
    
    [pool release];
    return (PyObject *) self;
}

static PyObject *
ImageObject_imageWithIconForFile(PyTypeObject *cls, PyObject *args)
{
    ImageObject *self;
    char *fileName_ = NULL;
    NSString *fileName = nil;
    NSImage *theImage = nil;
    NSAutoreleasePool *pool = nil;
    
    if (! PyArg_ParseTuple(args, "et:imageWithIconForFile",
                           Py_FileSystemDefaultEncoding, &fileName_))
        return NULL;
        
    pool = [[NSAutoreleasePool alloc] init];
    
    fileName = [NSString stringWithUTF8String:fileName_];
    theImage = [[NSWorkspace sharedWorkspace] iconForFile:fileName];
    self = newImageObject(theImage);
    
    [pool release];
    return (PyObject *) self;
}

static PyObject *
ImageObject_imageWithIconForFileType(PyTypeObject *cls, PyObject *args)
{
    ImageObject *self;
    char *fileType = NULL;
    NSImage *theImage = nil;
    NSAutoreleasePool *pool = nil;
    
    if (! PyArg_ParseTuple(args, "s:imageWithIconForFileType",
                           &fileType))
        return NULL;
        
    pool = [[NSAutoreleasePool alloc] init];
    
    theImage = [[NSWorkspace sharedWorkspace] iconForFileType:[NSString stringWithUTF8String:fileType]];
    self = newImageObject(theImage);
    
    [pool release];
    return (PyObject *) self;
}

static PyObject *
ImageObject_imageWithIconForCurrentApplication(PyTypeObject *cls, PyObject *args)
{
    ImageObject *self;
    NSAutoreleasePool *pool = nil;
    
    if (! PyArg_ParseTuple(args, ":imageWithIconForCurrentApplication"))
        return NULL;
        
    pool = [[NSAutoreleasePool alloc] init];
    
    self = newImageObject([NSApp applicationIconImage]);
    
    [pool release];
    return (PyObject *) self;
}

static PyObject *
ImageObject_imageWithIconForApplication(PyTypeObject *cls, PyObject *args)
{
    ImageObject *self;
    char *appName_ = NULL;
    NSString *appName = nil;
    NSString *appPath = nil;
    NSImage *theImage = nil;
    NSAutoreleasePool *pool = nil;
    
    if (! PyArg_ParseTuple(args, "et:imageWithIconForApplication",
                           Py_FileSystemDefaultEncoding, &appName_))
        return NULL;
        
    pool = [[NSAutoreleasePool alloc] init];
    
    appName = [NSString stringWithUTF8String:appName_];
    appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:appName];
    if (! appPath)
    {
        PyErr_Format(PyExc_RuntimeError, "Application named '%s' not found", appName_);
        self = NULL;
        goto done;
    }
    theImage = [[NSWorkspace sharedWorkspace] iconForFile:appPath];
    self = newImageObject(theImage);

done:
    [pool release];
    return (PyObject *) self;
}


static PyMethodDef ImageObject_methods[] = {
    {"imageFromPath", (PyCFunction)ImageObject_imageFromPath, METH_VARARGS | METH_CLASS},
    {"imageWithData", (PyCFunction)ImageObject_imageWithData, METH_VARARGS | METH_CLASS},
    {"imageWithIconForFile", (PyCFunction)ImageObject_imageWithIconForFile, METH_VARARGS | METH_CLASS},
    {"imageWithIconForFileType", (PyCFunction)ImageObject_imageWithIconForFileType, METH_VARARGS | METH_CLASS},
    {"imageWithIconForCurrentApplication", (PyCFunction)ImageObject_imageWithIconForCurrentApplication, METH_VARARGS | METH_CLASS},
    {"imageWithIconForApplication", (PyCFunction)ImageObject_imageWithIconForApplication, METH_VARARGS | METH_CLASS},
    {NULL, NULL} /* sentinel */
};

static PyTypeObject ImageObject_Type = {
        PyObject_HEAD_INIT(NULL)
        0,                      /*ob_size*/
        "_growlImage.Image",    /*tp_name*/
        sizeof(ImageObject),    /*tp_basicsize*/
        0,                      /*tp_itemsize*/
        /* methods */
        (destructor)ImageObject_dealloc, /*tp_dealloc*/
        0,                      /*tp_print*/
        0,                      /*tp_getattr*/
        0,                      /*tp_setattr*/
        0,                      /*tp_compare*/
        0,                      /*tp_repr*/
        0,                      /*tp_as_number*/
        0,                      /*tp_as_sequence*/
        0,                      /*tp_as_mapping*/
        0,                      /*tp_hash*/
        0,                      /*tp_call*/
        0,                      /*tp_str*/
        ImageObject_getAttr,    /*tp_getattro*/
        0,                      /*tp_setattro*/
        0,                      /*tp_as_buffer*/
        Py_TPFLAGS_DEFAULT | Py_TPFLAGS_HAVE_CLASS,     /*tp_flags*/
        0,                      /*tp_doc*/
        0,                      /*tp_traverse*/
        0,                      /*tp_clear*/
        0,                      /*tp_richcompare*/
        0,                      /*tp_weaklistoffset*/
        0,                      /*tp_iter*/
        0,                      /*tp_iternext*/
        ImageObject_methods,    /*tp_methods*/
        0,                      /*tp_members*/
        0,                      /*tp_getset*/
        0,                      /*tp_base*/
        0,                      /*tp_dict*/
        0,                      /*tp_descr_get*/
        0,                      /*tp_descr_set*/
        0,                      /*tp_dictoffset*/
        0,                      /*tp_init*/
        PyType_GenericAlloc,    /*tp_alloc*/
        0,                      /*tp_new*/
        0,                      /*tp_free*/
        0,                      /*tp_is_gc*/
};

static PyMethodDef _growlImage_methods[] = {
    {NULL, NULL}
};

PyMODINIT_FUNC
init_growlImage(void)
{
    PyObject *m;
    
    if (PyType_Ready(&ImageObject_Type) < 0)
        return;
    
    m = Py_InitModule("_growlImage", _growlImage_methods);
    
    PyModule_AddObject(m, "Image", (PyObject *)&ImageObject_Type);
}
