#ifdef PLATFORM_LINUX
#include "SharedFiles/MPLinux.h"
#endif
#pragma once

namespace APE
{

// disable the operator -> on UDT warning
#ifdef _MSC_VER
    #pragma warning(push)
    #pragma warning(disable : 4284)
#endif

/*************************************************************************************************
CSmartPtr - a simple smart pointer class that can automatically initialize and free memory
    note: (doesn't do garbage collection / reference counting because of the many pitfalls)
*************************************************************************************************/
template <class TYPE> class CSmartPtr
{
public:
    TYPE * m_pObject;
    bool m_bArray;
    bool m_bDelete;

    CSmartPtr()
    {
        m_bDelete = true;
        m_pObject = NULL;
    }
    CSmartPtr(TYPE * a_pObject, bool a_bArray = false, bool a_bDelete = true)
    {
        m_bDelete = true;
        m_pObject = NULL;
        Assign(a_pObject, a_bArray, a_bDelete);
    }

    ~CSmartPtr()
    {
        Delete();
    }

    void Assign(TYPE * a_pObject, bool a_bArray = false, bool a_bDelete = true)
    {
        Delete();

        m_bDelete = a_bDelete;
        m_bArray = a_bArray;
        m_pObject = a_pObject;
    }

    void Delete()
    {
        if (m_bDelete && m_pObject)
        {
            if (m_bArray)
                delete [] m_pObject;
            else
                delete m_pObject;

            m_pObject = NULL;
        }
    }

    void SetDelete(const bool a_bDelete)
    {
        m_bDelete = a_bDelete;
    }

    __forceinline TYPE * GetPtr() const
    {
        return m_pObject;
    }

    __forceinline operator TYPE * () const
    {
        return m_pObject;
    }

    __forceinline TYPE * operator ->() const
    {
        return m_pObject;
    }

    // declare assignment, but don't implement (compiler error if we try to use)
    // that way we can't carelessly mix smart pointers and regular pointers
    __forceinline void * operator =(void *) const;
};

#ifdef _MSC_VER
    #pragma warning(pop)
#endif

}
