#include-once
#include <StringConstants.au3>
#include <AutoItConstants.au3>

Global Const $__g_HashMap_Integer_MAX_VALUE = 2^31 - 1

;FIXME: bit operations should use lib, to allow 64bit bitwise operations

#cs
# Hashing logic based on Java 8 (jdk8)
#
# NOTE: the case to convert buckets to trees when the hashmap get over a certain threshold is not implemented. There seems no good fast way to do this in AutoIt3, for now.
#
# @see https://docs.oracle.com/javase/8/docs/api/java/util/Hashtable.html
# @see https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/util/HashMap.java
#ce

#cs
# The default initial capacity - MUST be a power of two.
#ce
Global Const $__g_HashMap_DEFAULT_INITIAL_CAPACITY = BitShift(1, -4) ; aka 16

#cs
# The maximum capacity, used if a higher value is implicitly specified
# by either of the constructors with arguments.
# MUST be a power of two <= 1<<30.
#ce
Global Const $__g_HashMap_MAXIMUM_CAPACITY = BitShift(1, -30)

#cs
# The load factor used when none specified in constructor.
#ce
Global Const $__g_HashMap_DEFAULT_LOAD_FACTOR = 0.75

Global Enum _; "Class" properties
$__g_HashMap_Property_table, _
$__g_HashMap_Property_entrySet, _
$__g_HashMap_Property_size, _
$__g_HashMap_Property_modCount, _
$__g_HashMap_Property_threshold, _
$__g_HashMap_Property_loadFactor, _
$__g_HashMap_Property_MAX

Global Enum _; Node "Class" properties
$__g_HashMap_Node_Property_hash, _
$__g_HashMap_Node_Property_key, _
$__g_HashMap_Node_Property_value, _
$__g_HashMap_Node_Property_MAX

Func _HashMap_Create($iInitialCapacity = $__g_HashMap_DEFAULT_INITIAL_CAPACITY, $fLoadFactor = $__g_HashMap_DEFAULT_LOAD_FACTOR)
    ;Local $aTable[$iInitialCapacity][1][3]
    Local Static $aHashMap[$__g_HashMap_Property_MAX]
        $aHashMap[$__g_HashMap_Property_table] = Null
        $aHashMap[$__g_HashMap_Property_entrySet] = Null
        $aHashMap[$__g_HashMap_Property_size] = 0
        $aHashMap[$__g_HashMap_Property_modCount] = 0

        $aHashMap[$__g_HashMap_Property_loadFactor] = $fLoadFactor
        $aHashMap[$__g_HashMap_Property_threshold] = _HashMap_TableSizeFor($iInitialCapacity)

    ;[hashId][bucketId][bucketInfo]

    Return $aHashMap
EndFunc

#cs
# Returns a power of two size for the given target capacity.
#
# @param integer $iCap
#
# @return integer
#
# @see https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/util/HashMap.java#l377
#ce
Func _HashMap_TableSizeFor($iCap)
    Local $n = $iCap - 1
        $n = BitOR($n, BitShift($n, 1))
        $n = BitOR($n, BitShift($n, 2))
        $n = BitOR($n, BitShift($n, 4))
        $n = BitOR($n, BitShift($n, 8))
        $n = BitOR($n, BitShift($n, 16))
    Return ($n < 0) ? 1 : ($n >= $__g_HashMap_MAXIMUM_CAPACITY) ? $__g_HashMap_MAXIMUM_CAPACITY : $n + 1
EndFunc

#cs
# Computes key.hashCode() and spreads (XORs) higher bits of hash
# to lower.  Because the table uses power-of-two masking, sets of
# hashes that vary only in bits above the current mask will
# always collide. (Among known examples are sets of Float keys
# holding consecutive whole numbers in small tables.)  So we
# apply a transform that spreads the impact of higher bits
# downward. There is a tradeoff between speed, utility, and
# quality of bit-spreading. Because many common sets of hashes
# are already reasonably distributed (so don't benefit from
# spreading), and because we use trees to handle large sets of
# collisions in bins, we just XOR some shifted bits in the
# cheapest possible way to reduce systematic lossage, as well as
# to incorporate impact of the highest bits that would otherwise
# never be used in index calculations because of table bounds.
#
# @param mixed $vKey
#
# @return integer
#
# @see https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/util/HashMap.java#l336
#ce
Func _HashMap_Hash($vKey)
    If $vKey = Null Then
        Return 0
    EndIf

    ; Java 8 Primitive datatype ref: https://docs.oracle.com/javase/tutorial/java/nutsandbolts/datatypes.html
    Local Static $h = 0
    Switch VarGetType($vKey)
        Case "Array"
            $h = _HashMap_HashArray($vKey)
        Case "Binary"
            $h = _HashMap_HashBinary($vKey)
        Case "Bool"
            $h = _HashMap_HashBoolean($vKey)
        Case "Ptr"
            $h = _HashMap_HashPtr($vKey)
        Case "Int32"
            $h = _HashMap_HashInteger($vKey)
        Case "Int64";FIXME: Int64? (Int64 should be treated as Long?)
            $h = _HashMap_HashLong($vKey)
        Case "Double"
            $h = _HashMap_HashDouble($vKey)
        Case "String"
            $h = _HashMap_HashString($vKey)
        Case "DLLStruct"
            $h = _HashMap_HashPtr(DllStructGetPtr($vKey))
        Case "Keyword"
            $h = 0;WARNING: we treat all keywords as Null, but if this is correct is unsure for now!
        Case "Function"
            ContinueCase
        Case "UserFunction"
            ; https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/lang/reflect/Method.java#l315
            $h = _HashMap_HashString(FuncName($vKey))
        Case "Map";WARNING: not tested!
            ;FIXME: implement
        Case Else
            ;FIXME: "Throw" error
    EndSwitch

    Return BitXOR($h, BitShift($h, 16))
EndFunc

; https://hg.openjdk.java.net/jdk8u/jdk8u/jdk/file/be44bff34df4/src/share/classes/java/util/Arrays.java#l3915
; https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/util/AbstractList.java#l538
Func _HashMap_HashArray($aArray)
    ;FIXME: support multi dimention arrays!
    Local $hashCode = 1
    For $e In $aArray
        $hashCode = 31*$hashCode + _HashMap_Hash($e)
    Next
    Return $hashCode
EndFunc

; https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/lang/Byte.java#l405
; https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/util/AbstractList.java#l538
Func _HashMap_HashBinary($dBinary)
    ;we treat it like the equivelent of Java 8 byte[]
    Local $tBinary = DllStructCreate(StringFormat("BYTE[%s]", BinaryLen($dBinary)))
        DllStructSetData($dBinary, 1, $dBinary)
    Local $hashCode = 1
    For $i = 0 To BinaryLen($dBinary) Step +1
        ;NOTE: DllStructGetData on byte gives int32, no reason to wase time on re-cast
        $hashCode = 31*$hashCode + DllStructGetData($tBinary, 1, $i + 1)
    Next
EndFunc

; https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/lang/Boolean.java#l212
Func _HashMap_HashBoolean($bBoolean)
    Return $bBoolean ? 1231 : 1237
EndFunc

; https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/lang/Integer.java#l959
Func _HashMap_HashInteger($iInterger)
    Return $iInterger
EndFunc

;https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/lang/Long.java#l1060
Func _HashMap_HashLong($nLong)
    Return Int(BitXOR($nLong, BitShift($nLong, 32)), 1)
EndFunc

; https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/lang/Double.java#l753
Func _HashMap_HashDouble($dbDouble)
    ;$bits = doubleToLongBits()
    Local $bits = $dbDouble ;NOTE: we do not have LONG type as a native AutoIt3 type, so we assume that for now this will work.
    Return Int(BitXOR($bits, BitShift($bits, 32))) ;WARNING: may produce wrong result, compared to source!
EndFunc

; https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/lang/Double.java#l835
Func _HashMap_HashDouble_DoubleToLongBits($dbDouble)
    Local $result = _HashMap_HashDouble_DoubleToRawLongBits($dbDouble)
    ; Check for NaN based on values of bit fields, maximum
    ; exponone and nonzero significand
    If (BitAND($result, $__g_HashMap_DoubleConsts_EXP_BIT_MASK) = $__g_HashMap_DoubleConsts_EXP_BIT_MASK And (Not (BitAND($result, $__g_HashMap_DoubleConsts_SIGNUF_BIT_MASK) = 0))) Then $result = 0x7ff8000000000000
    Return $result
EndFunc

; https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/lang/Double.java#l882
Func _HashMap_HashDouble_DoubleToRawLongBits()
    ;
EndFunc

; https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/lang/String.java#l1452
Func _HashMap_HashString($sString)
    If StringLen($sString) = 0 Then Return 0
    Local $h = 0
    Local $tString = DllStructCreate(StringFormat("WCHAR[%s]", StringLen($sString)))
        DllStructSetData($tString, 1, $sString)
    Local $val = DllStructCreate(StringFormat("WORD[%s]", StringLen($sString)), DllStructGetPtr($tString))
    For $i = 0 To StringLen($sString) Step +1
        $h = 31 * $h + DllStructGetData($val, 1, $i + 1)
    Next
    Return $h
EndFunc

Func _HashMap_HashPtr($pPtr)
    ;WARNING: converting ptr to int(32/64) has not been tested, and may result in unexpected results.
    Return @AutoItX64 ? _HashMap_HashLong(Int($pPtr, 2)) : _HashMap_HashInteger(Int($pPtr, 1))
EndFunc

Func _HashMap_Size(ByRef $aHashMap)
    Return $aHashMap[$__g_HashMap_Property_size]
EndFunc

Func _HashMap_IsEmpty(ByRef $aHashMap)
    Return $aHashMap[$__g_HashMap_Property_size] = 0
EndFunc

Func _HashMap_Get(ByRef $aHashMap, $vKey)
    Local $e = _HashMap_GetNode($aHashMap, _HashMap_Hash($vKey), $vKey)
    Return $e = Null ? Null : $e[$__g_HashMap_Node_Property_value]
EndFunc

Func _HashMap_GetNode(ByRef $aHashMap, $iHash, $vKey)
    Return _HashMap_GetNode_GetNode($aHashMap[$__g_HashMap_Property_table], $iHash, $vKey)
EndFunc

#cs
# This is needed to use array byref, instead of copying it. Currently AutoIt3 does not allow byref for variable assignments outside function variables.
#ce
Func _HashMap_GetNode_GetNode(ByRef $tab, ByRef $iHash, ByRef $vKey)
    If Not ($tab = Null) Then
        Local $n = UBound($tab, 1)
        If ($n > 0) Then
            ;NOTE: here we deviate from Java source, because we use array and not an actual node structure, we need to loop everything right away
            Local $tableIndex = BitAND($n - 1, $iHash)
            Local Static $node[$__g_HashMap_Node_Property_MAX]
            For $i = 0 To UBound($tab, 2) - 1 Step +1
                If $tab[$tableIndex][$i][$__g_HashMap_Node_Property_hash] = $iHash And $tab[$tableIndex][$i][$__g_HashMap_Node_Property_key] = $vKey Then
                    For $j = 0 To $__g_HashMap_Node_Property_MAX - 1 Step +1
                        $node[$j] = $tab[$tableIndex][$i][$j]
                    Next
                    Return $node
                EndIf
            Next
        EndIf
    EndIf
    Return Null
EndFunc

Func _HashMap_ContainsKey(ByRef $aHashMap, $vKey)
    Return Not (_HashMap_GetNode($aHashMap, _HashMap_Hash($vKey), $vKey) = Null)
EndFunc

Func _HashMap_Put(ByRef $aHashMap, $vKey, $vValue)
    Return _HashMap_PutVal($aHashMap, _HashMap_Hash($vKey), $vKey, $vValue, False, True)
EndFunc

#cs
# Implements Map.put and related methods
#
# @param integer $iHash         hash for key
# @param mixed   $vKey          the key
# @param mixed   $vValue        the value to put
# @param boolean $bOnlyIfAbsent if true, don't change existing value
# @param boolean $bEvict        if false, the table is in creation mode
#
# @return mixed previous value, or null if none
#
# @see https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/util/HashMap.java#l624
#ce
Func _HashMap_PutVal(ByRef $aHashMap, $iHash, $vKey, $vValue, $bOnlyIfAbsent, $bEvict)
    Local Static $node[$__g_HashMap_Node_Property_MAX]
        $node[$__g_HashMap_Node_Property_hash] = $iHash
        $node[$__g_HashMap_Node_Property_key] = $vKey
        $node[$__g_HashMap_Node_Property_value] = $vValue
    Local $n = 0
    Local $tab = $aHashMap[$__g_HashMap_Property_table] ;Not sure if the table array is copied, when used in the if case, if not, a small performance upgrade could be made here by using the var $tab instead of $aHashMap[$__g_HashMap_Property_table] on read access
    If $tab = Null Or UBound($tab, 1) = 0 Then
        _HashMap_Resize($aHashMap)
        $tab = $aHashMap[$__g_HashMap_Property_table]
        $n = UBound($tab, 1)
    Else
        $n = UBound($tab, 1)
    EndIf
    Local $i = BitAND($n - 1, $iHash)
    If _HashMap_IsNullish($tab[$i][0][$__g_HashMap_Node_Property_hash]) Then
        Return _HashMap_PutVal_TableAssign($aHashMap[$__g_HashMap_Property_table], $i, 0, $node)
    Else
        Local $k = $tab[$i][0][$__g_HashMap_Node_Property_key]
        if ($tab[$i][0][$__g_HashMap_Node_Property_hash] = $iHash And $k = $vKey) Then
            Return _HashMap_PutVal_TableAssign($aHashMap[$__g_HashMap_Property_table], $i, 0, $node)
        Else ;NOTE: Here we don't implement the TreeNode part of the Java 8 implementation. There is no fast and native way to do this in AutoIt3
            For $_i = 1 To UBound($tab, 2) - 1 Step +1
                if ($tab[$i][$_i][$__g_HashMap_Node_Property_hash] = $iHash And $tab[$i][$_i][$__g_HashMap_Node_Property_key] = $vKey) Then
                    Return _HashMap_PutVal_TableAssign($aHashMap[$__g_HashMap_Property_table], $_i, 0, $node)
                EndIf
            Next
        EndIf
    EndIf
    
    Return Null
EndFunc

#cs
# This exists because how AutoIt is with arrays and references to change something
#ce
Func _HashMap_PutVal_TableAssign(ByRef $aTable, $i, $j, $value)
    Local Static $node[$__g_HashMap_Node_Property_MAX]
    For $_i = 0 To UBound($value) - 1 Step +1
        $node[$_i] = $aTable[$i][$j][$_i]
        $aTable[$i][$j][$_i] = $value[$_i]
    Next
    If _HashMap_IsNullish($node[$__g_HashMap_Node_Property_hash]) Then Return Null
    Return $node
EndFunc

Func _HashMap_Remove(ByRef $aHashMap, $vKey)
    Return True;FIXME: implement
EndFunc

Func _HashMap_Clear(ByRef $aHashMap, $vKey)
    Return True;FIXME: implement
EndFunc

; https://hg.openjdk.java.net/jdk8/jdk8/jdk/file/687fd7c7986d/src/share/classes/java/util/HashMap.java#l676
Func _HashMap_Resize(ByRef $aHashMap)
    Local $oldTab = $aHashMap[$__g_HashMap_Property_table]
    Local $oldCap = ($oldTab = Null) ? 0 : UBound($oldTab, 1)
    Local $oldThr = $aHashMap[$__g_HashMap_Property_threshold]
    Local $newCap = 0, $newThr = 0

    If ($oldCap > 0) Then
        If ($oldCap >= $__g_HashMap_MAXIMUM_CAPACITY) Then
            $aHashMap[$__g_HashMap_Property_threshold] = $__g_HashMap_Integer_MAX_VALUE
            Return $oldTap;TODO: do we need to return the array? or is it just a waste of cycles
        ElseIf (BitShift($oldCap, -1) < $__g_HashMap_MAXIMUM_CAPACITY && $oldCap >= $__g_HashMap_DEFAULT_INITIAL_CAPACITY) Then
            $newCap = BitShift($oldCap, -1)
            $newThr = BitShift($oldThr, -1) ; double threshold
        EndIf
    ElseIf ($oldThr > 0) Then ; initial capacity was placed in threshold
        $newCap = $oldThr
    Else ; zero initial threshold signifies using defaults
        $newCap = $__g_HashMap_DEFAULT_INITIAL_CAPACITY
        $newThr = Int($__g_HashMap_DEFAULT_LOAD_FACTOR * $__g_HashMap_DEFAULT_INITIAL_CAPACITY, 1)
    EndIf

    If ($newThr = 0) Then
        Local $ft = Number($newCap, $NUMBER_DOUBLE) * $aHashMap[$__g_HashMap_Property_loadFactor];WARNING: original code casts to float! unexpected results may occur
        $newThr = ($newCap < $__g_HashMap_MAXIMUM_CAPACITY And $ft < Number($__g_HashMap_MAXIMUM_CAPACITY, $NUMBER_DOUBLE) ? Int($ft, 1) : $__g_HashMap_Integer_MAX_VALUE)
    EndIf

    $aHashMap[$__g_HashMap_Property_threshold] = $newThr
    Local $newTab[$newCap][$newCap][$__g_HashMap_Node_Property_MAX];WARNING: 2nd dimention of table array used to be a linkedlist, now is a static array, this may end up being resource intensive!
    $aHashMap[$__g_HashMap_Property_table] = $newTab
    If Not ($oldTab = Null) Then
        ;FIXME: implement
    EndIf

    Return $newTab;TODO: do we need to return the array? or is it just a waste of cycles
EndFunc

#cs
# AutoIt3 quirk helper function that checks if value is null or autoit default empty value (an empty string).
# @internal
# @param mixed $value
# @return boolean
#ce
Func _HashMap_IsNullish($value)
    Return $value = Null Or $value = ""
EndFunc
