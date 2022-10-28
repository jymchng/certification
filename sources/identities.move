module identities::certificates {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::string;
    use sui::typed_id::{Self, TypedID};
    use sui::table::{Self, Table}

    const ENoPermissionToVerify: u64 = 0;
    const ENoFieldInPermission: u64 = 1;
    const ENameIsIncorrect: u64 = 2;
    const EVerifyWhatInPermissionIsNotName: u64 = 3;
    const EYearIsIncorrect: u64 = 4;

    struct CertCreatorCap has key, store {
        id: UID,
    }
    
    // has no drop
    struct Certificate has key, store {
        id: UID,
        name: Name,
        year: Year,
    }

    struct GrantPermissionsCap has key, store {
        id: UID,
        certificate_id: TypedID<Certificate>,
    }

    struct Permission<phantom T: store> has key {
        id: UID,
        certificate_id: TypedID<Certificate>, // TypedID has drop
    }

    struct Year has store, drop { // has drop for easier dropping
        value: u128,
    }

    struct Name has store, drop {
        value: string::String,
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(
            CertCreatorCap {
                id: object::new(ctx),
            },
            tx_context::sender(ctx)
        );
        transfer::transfer(
            table::new<TypedID<Certificate>, Certificate>(),
            tx_context::sender(ctx)
        );
    }

    // allow recipient to request a certificate instead of issue it directly
    public entry fun issue_certificate(_: &CertCreatorCap,
        name_: vector<u8>,
        year_: u128,
        certificates_table: &mut Table<TypedID<Certificate>, Certificate>,
        certificate_recipient: address,
        ctx: &mut TxContext
        ) {
            let certificate = Certificate {
                id: object::new(ctx),
                name: Name { value: name_ },
                year: Year { value: year_ },
            }; // make the certificate

            let certificate_id = typed_id::new(certificate);
            table::add(certificates_table, certificate_id, certificate); // add the certificate to the table

            let grant_permissions_cap = GrantPermissionsCap {
                id: object::new(ctx),
                certificate_id: certificate_id,
            }; // make the capability for granting permissions

            transfer::transfer(
                grant_permissions_cap,
                tx_context::sender(ctx),
            ) // transfer that capability
    }

    // certificate is non-transferable but can be destroyed. need to think of safe-transfer logic to new address.
    public entry fun destroy_certificate(certificate: Certificate) {
        let Certificate {id, name: _, year: _} = certificate;
        object::delete(id);
    }

    public entry fun give_permission_verify_certificate(grand_permission: &GrantPermissionsCap, recipient: address, ctx: &mut TxContext) { 
        transfer::transfer(
            Permission<Certificate> {
            id: object::new(ctx),
            certificate_id: grand_permission.certificate_id,
        },
            recipient
        )
    }

    public entry fun give_permission_verify_name(grand_permission: &GrantPermissionsCap, recipient: address, ctx: &mut TxContext) { 
        transfer::transfer(
            Permission<Name> {
            id: object::new(ctx),
            certificate_id: grand_permission.certificate_id,
        },
            recipient
        )
    }

    public entry fun give_permission_verify_year(grand_permission: &GrantPermissionsCap, recipient: address, ctx: &mut TxContext) { 
        transfer::transfer(
            Permission<Year> {
            id: object::new(ctx),
            certificate_id: grand_permission.certificate_id,
        },
            recipient
        )
    }
                                        // OWNER A owns certificate  // OWNER B owns permission
    public entry fun verify_certificate(permission: Permission<Certificate>, _ctx: &mut TxContext) {
        let Permission { id, certificate_id: certificate_id,} = permission;
        object::delete(id);
    } // intent is to make OWNER B to call this function to verify the authenticity of the certificate possess by OWNER A

    public entry fun verify_name(certificate: &Certificate, permission: Permission<string::String>, name: vector<u8>, _ctx: &mut TxContext) {
        assert!(typed_id::equals_object(&permission.certificate_id, certificate), ENoPermissionToVerify);
        let name = string::utf8(name);
        assert!(name==certificate.name, ENameIsIncorrect);
        let Permission { id, certificate_id: _,} = permission;
        object::delete(id);
    }

    public entry fun verify_year(certificate: &Certificate, permission: Permission<u128>, year: u128, _ctx: &mut TxContext) {
        assert!(typed_id::equals_object(&permission.certificate_id, certificate), ENoPermissionToVerify);
        assert!(year==certificate.year, EYearIsIncorrect);
        let Permission { id, certificate_id: _,} = permission;
        object::delete(id);
    }
}