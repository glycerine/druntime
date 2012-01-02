module core.refcounted;

public import core.allocator;
import core.atomic;
import core.stdc.string; // for memcpy

abstract class RefCountedBase
{
private:
  int m_iRefCount = 0;
  
  final void AddReference()
  {
    atomicOp!"+="(m_iRefCount,1);
  }
  
  // RemoveRefernce needs to be private otherwise the invariant handler
  // gets called on a already destroyed and freed object
  final void RemoveReference()
  {
    int result = atomicOp!"-="(m_iRefCount,1);
    assert(result >= 0,"ref count is invalid");
    if(result == 0)
    {
      this.Release();
    }
  }
    
  final void AddReference() shared
  {
    (cast(RefCountedBase)this).AddReference();
  }
  
  final void RemoveReference() shared
  {
    (cast(RefCountedBase)this).RemoveReference();
  }

protected:
  // Release also needs to be private so that the invariant handler does not get
  // called on a already freed object
  abstract void Release();
  
  final void Release() shared
  {
    (cast(RefCountedBase)this).Release();
  }
  
public:
  @property final int refcount()
  {
    return m_iRefCount;
  }
}

abstract class RefCountedImpl(T) : RefCountedBase
{
public:
  alias T allocator_t;

protected:
  override void Release()
  {
    clear(this);
    T.FreeMemory(cast(void*)this);
  }
}

alias RefCountedImpl!StdAllocator RefCounted;

struct SmartPtr(T)
{
  static assert(is(T : RefCountedBase),T.stringof ~ " is not a reference counted object");
  
  T ptr;
  alias ptr this;
  alias typeof(this) this_t;
  
  this(T obj)
  {
    ptr = obj;
    ptr.AddReference();
  }
  
  this(const(T) obj) const
  {
    ptr = obj;
    (cast(T)ptr).AddReference();
  }
  
  this(immutable(T) obj) immutable
  {
    ptr = obj;
    (cast(T)ptr).AddReference();
  }
  
  this(this)
  {
    if(ptr !is null)
      ptr.AddReference();
  }
  
  ~this()
  {
    if(ptr !is null)
      ptr.RemoveReference();
  }
  
  static if(is(null_t))
  {
    pragma(msg,"we have a null_t");
    void opAssign(null_t obj)
    {
      if(ptr !is null)
        ptr.RemoveReference();
      ptr = null;
    }
  }
  
  void opAssign(T obj)
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = obj;
    if(ptr !is null)
      ptr.AddReference();
  }
  
  void opAssign(shared(T) obj) shared
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = obj;
    if(ptr !is null)
      ptr.AddReference();
  }
  
  void opAssign(ref this_t rh)
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = rh.ptr;
    if(ptr !is null)
      ptr.AddReference();
  }
  
  void opAssign(ref shared(this_t) rh) shared
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = rh.ptr;
    if(ptr !is null)
      ptr.AddReference();
  }
}

final class RCArrayData(T,AT = StdAllocator) : RefCountedImpl!AT
{
private:
  T[] data;
  
public:
  this()
  {
    assert(0,"should never be called");
  }
  
  static auto AllocateArray(InitializeMemoryWith meminit = InitializeMemoryWith.INIT)
                           (size_t size, bool doInit = true)
  {
    //TODO replace enforce
    //enforce(size > 0,"can not create a array of size 0");
    size_t headerSize = __traits(classInstanceSize,typeof(this));
    size_t bytesToAllocate = headerSize + (T.sizeof * size);
    void* mem = allocator_t.AllocateMemory(bytesToAllocate);
    auto address = cast(size_t)mem;
    assert(address % T.alignof == 0,"Missaligned array memory");
    void[] blop = mem[0..bytesToAllocate];
    
    //initialize header
    (cast(byte[]) blop)[0..headerSize] = typeid(typeof(this)).init[];
    auto result = cast(typeof(this))mem;
    
    static if(meminit == InitializeMemoryWith.NULL)
    {
      if(doInit)
        memset(mem + headerSize,0,bytesToAllocate - headerSize);
    }
    static if(meminit == InitializeMemoryWith.INIT)
    {
      if(doInit)
      {
        auto arrayData = (cast(T*)(mem + headerSize))[0..size];
        foreach(ref T e; arrayData)
        {
          // If it is a struct cant use the assignment operator
          // otherwise the assignment operator might work on a non initialized instance
          static if(is(T == struct))
            memcpy(&e,&T.init,T.sizeof);
          else
            e = T.init;
        }
      }
    }   
    
    result.data = (cast(T*)(mem + headerSize))[0..size];
    return result;
  }
  
  private @property final size_t length() immutable
  {
    return data.length;
  }
  
  final auto Resize(InitializeMemoryWith meminit = InitializeMemoryWith.INIT)
                   (size_t newSize, bool doInit = true)
  {
    assert(newSize > data.length,"can not resize to smaller size");
    
    size_t headerSize = __traits(classInstanceSize,typeof(this));
    size_t bytesToAllocate = headerSize + (T.sizeof * newSize);
    void* mem = allocator_t.ReallocateMemory(cast(void*)this,bytesToAllocate);
    
    auto result = cast(typeof(this))mem;
    
    static if(meminit == InitializeMemoryWith.NULL)
    {
      if(doInit)
        memset(mem + headerSize + result.m_Length * T.sizeof,0,
               bytesToAllocate - headerSize + result.m_Length * T.sizeof);
    }
    static if(meminit == InitializeMemoryWith.INIT)
    {
      if(doInit)
      {
        auto arrayData = (cast(T*)(mem + headerSize))[result.data.length..newSize];
        foreach(ref T e; arrayData)
        {
          // If it is a struct we can not use the assignment operator
          // as the assignment operator will be calle don a non initialized instance
          static if(is(T == struct))
            memcpy(&e,&T.init,T.sizeof);
          else
            e = T.init;
        }
      }
    }   
    
    result.data = (cast(T*)(mem + headerSize))[0..newSize];
    return result;
  }
  
  private final auto opSlice()
  {
    return this.data;
  }
  
  private final auto opSlice() const
  {
    return this.data;
  }
  
  private final auto opSlice() immutable
  {
    return this.data;
  }
  
  private final auto opSlice() shared
  {
    return this.data;
  }
  
}

struct RCArray(T,AT = StdAllocator)
{
  alias RCArrayData!(T,AT) data_t;
  alias typeof(this) this_t;
  private data_t m_DataObject;
  private T[] m_Data;
  
  
  this(size_t size){
    m_DataObject = data_t.AllocateArray(size);
    m_DataObject.AddReference();
    m_Data = m_DataObject.data;
  }
  
  private void ConstructFromArray(U)(U init) 
    if(is(U : T[]) || is(U : immutable(T[])) || is(U : const(T[])))
  {
    m_DataObject = data_t.AllocateArray(init.length,false);
    m_DataObject.AddReference();
    m_Data = m_DataObject.data;
    m_Data[] = cast(T[])init[];
  }
  
  this(T[] init) 
  {
    ConstructFromArray(init);
  }
  
  this(const(T[]) init)
  {
    ConstructFromArray(init);
  }
  
  this(immutable(T[]) init)
  {
    ConstructFromArray(init);
  }
  
  //post blit constructor
  this(this)
  {
    if(m_DataObject !is null)
      m_DataObject.AddReference();
  }
  
  this(ref immutable(this_t) rh) immutable
  {
    m_DataObject = rh.m_DataObject;
    (cast(data_t)m_DataObject).AddReference();
    m_Data = rh.m_Data;
  }
  
  this(ref const(this_t) rh) const
  {
    m_DataObject = rh.m_DataObject;
    (cast(data_t)m_DataObject).AddReference();
    m_Data = rh.m_Data;
  }
  
  private this(data_t data)
  {
    m_DataObject = data;
    m_DataObject.AddReference();
    m_Data = m_DataObject.data;
  }
  
  private this(data_t dataObject, T[] data)
  {
    m_DataObject = dataObject;
    m_DataObject.AddReference();
    m_Data = data;
  }
  
  private this(const(data_t) dataObject, const(T[]) data) const
  {
    m_DataObject = dataObject;
    (cast(data_t)m_DataObject).AddReference();
    m_Data = data;
  }
  
  private this(immutable(data_t) dataObject, immutable(T[]) data) immutable
  {
    m_DataObject = dataObject;
    (cast(data_t)m_DataObject).AddReference();
    m_Data = data;
  }
    
  ~this()
  {
    if(m_DataObject !is null)
      m_DataObject.RemoveReference();
  }
  
  void opAssign(this_t rh) 
  {
    if(m_DataObject !is null)
      m_DataObject.RemoveReference();
    m_DataObject = rh.m_DataObject;
    m_Data = rh.m_Data;
    if(m_DataObject !is null)
      m_DataObject.AddReference();
  }
  
  /*void opAssign(ref shared(this_t) rh) shared
  {
    if(m_DataObject !is null)
      m_DataObject.RemoveReference();
    m_DataObject = rh.m_DataObject;
    m_Data = rh.m_Data;
    if(m_DataObject !is null)
      m_DataObject.AddReference();
  }*/
  
  this_t dup()
  {
    assert(m_Data !is null,"nothing to duplicate");
    auto copy = data_t.AllocateArray(m_Data.length,false);
    copy.data[0..m_Data.length] = m_Data[0..$];
    return this_t(copy);
  }
  
  immutable(this_t) idup()
  {
    return cast(immutable(this_t))dup();
  }
  
  ref T opIndex(size_t index)
  {
    return m_Data[index];
  }
  
  ref const(T) opIndex(size_t index) const
  {
    return m_Data[index];
  }
  
  ref immutable(T) opIndex(size_t index) immutable
  {
    return m_Data[index];
  }
  
  ref shared(T) opIndex(size_t index) shared
  {
    return m_Data[index];
  }
  
  T[] opSlice()
  {
    assert(m_DataObject !is null,"can not slice empty array");
    return m_DataObject.data;
  }
  
  this_t opSlice(size_t start, size_t end)
  {
    assert(m_DataObject !is null,"can not slice empty array");
    return this_t(m_DataObject,m_Data[start..end]);
  }
  
  const(this_t) opSlice(size_t start, size_t end) const
  {
    assert(m_DataObject !is null, "can not slice empty array");
    return const(this_t)(m_DataObject, m_Data[start..end]);
  }
  
  immutable(this_t) opSlice(size_t start, size_t end) immutable
  {
    assert(m_DataObject !is null, "can not slice empty array");
    return immutable(this_t)(m_DataObject, m_Data[start..end]);
  }
  
  void opOpAssign(string op,U)(U rh) if(op == "~" && (is(U == this_t) || is(U : T[]) || is(U : immutable(T[]))))
  {
    // We own the data and therefore can do whatever we want with it
    if(m_DataObject !is null && m_DataObject.refcount == 1)
    {
      m_DataObject = m_DataObject.Resize!(InitializeMemoryWith.NOTHING)
                                         (m_Data.length + rh.length);
      m_DataObject.data[m_Data.length..$] = rh[];
      m_Data = m_DataObject.data;
    }
    else { // we have to copy the data
      auto newData = data_t.AllocateArray(m_Data.length + rh.length, false);
      if(m_DataObject !is null)
      {
        m_DataObject.RemoveReference();
        newData.data[0..m_Data.length] = m_Data[];
        newData.data[m_Data.length..$] = rh[];
      }
      else
        newData.data[0..$] = rh[];

      m_DataObject = newData;
      m_DataObject.AddReference();
      m_Data = newData.data;
    }
  }
  
  void opOpAssign(string op,U)(U rh) if(op == "~" && is(U == T))
  {
    //We own the data
    if(m_DataObject !is null && m_DataObject.refcount == 1)
    {
      m_DataObject = m_DataObject.Resize(m_Data.length + 1);
      m_DataObject.data[m_Data.length] = rh;
      m_Data = m_DataObject.data;
    }
    else { // we have to copy the data
      auto newData = data_t.AllocateArray(m_Data.length + 1);
      if(m_DataObject !is null)
      {
        newData.data[0..m_Data.length] = m_Data[];
        newData.data[m_Data.length] = rh;
        m_DataObject.RemoveReference();
      }
      else
      {
        newData.data[m_Data.length] = rh;
      }
      m_DataObject = newData;
      m_DataObject.AddReference();
      m_Data = newData.data;
    }
  }
  
  /*void opOpAssign(string op,U)(U rh)
  {
    static assert(0,U.stringof);
  }*/
  
  int opApply( scope int delegate(ref T) dg )
  {
    int result;
    
    foreach( e; m_Data)
    {
      if( (result = dg( e )) != 0 )
        break;
    }
    return result;
  }
  
  int opApply( scope int delegate(ref size_t, ref T) dg )
  {
      int result;

      foreach( i, e; m_Data )
      {
          if( (result = dg( i, e )) != 0 )
              break;
      }
      return result;
  }
  
  @property auto ptr()
  {
    return m_Data.ptr;
  }
  
  @property size_t length()
  {
    return m_Data.length;
  }
}

version(unittest)
{
  import std.stdio;
}