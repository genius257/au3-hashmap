#include "hashmap.au3"

$aHashMap = _HashMap_Create()

_HashMap_Put($aHashMap, "key1", 123)
_HashMap_Put($aHashMap, "key2", 321)

ConsoleWrite("key1: " & _HashMap_Get($aHashMap, "key1")&@CRLF)

_HashMap_Remove($aHashMap, "key1")

ConsoleWrite("key1: " & _HashMap_Get($aHashMap, "key1")&@CRLF)
