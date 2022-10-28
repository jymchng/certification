# JUST FOR FUN

Building a certificate management system on SUI using sui-move a variant / dialect of the Move programming language.

# Requirements
1. Fields of Certificate should not be accessible via blockchain explorer, i.e. they should remain "private".
   E.g. a particular certificate: Certificate have fields `name` as 'John' and `year` as '1994' but these should not be shown on the blockchain explorer when queried.

**THIS SHOULD NOT HAPPEN**
```
\identities>sui client object --id 0xaf98a23d51c243be83c838f0f3f416d085870d74 
----- Move Object (0xaf98a23d51c243be83c838f0f3f416d085870d74[1]) -----
Owner: Account Address ( 0xb7a9c2bc3a65ad0b02851e426e6b34dcf069b6c7 )
Version: 1
Storage Rebate: 14
Previous Transaction: 6C+vV0woUHxlt0w5147/DZZJSIN701A6NBhXeVtTfhY=
----- Data -----
type: 0x426ff70c987a00b9384b102f10a4f8bb8945141f::certificates::Certificate
id: 0xaf98a23d51c243be83c838f0f3f416d085870d74
name: JIM
year: 22
```
2. The authority has a table of type Table<TypedID, Certificate>.
3. An address who has an entry in authority's table has a struct of type GrantPermissions which is a capability to spawn new instances of type Permission<T>. T can be any type of the fields of the Certificate or the Certificate type itself.
4. Once the address with a certificate, say 0xHasCert, grants