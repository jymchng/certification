module identities::certificates {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::string;
    use sui::typed_id::{Self, TypedID};

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
        name: string::String,
        year: u128,
    }

    struct Permission<phantom T: store> has key {
        id: UID,
        certificate_id: TypedID<Certificate>, // TypedID has drop
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(
            CertCreatorCap {
                id: object::new(ctx),
            },
            tx_context::sender(ctx)
        )
    }

    // allow recipient to request a certificate instead of issue it directly
    public entry fun issue_certificate(_: &CertCreatorCap, name: vector<u8>, year: u128, recipient: address, ctx: &mut TxContext) {
        transfer::transfer(
            Certificate {
            id: object::new(ctx),
            name: string::utf8(name),
            year: year,
        },
        recipient
        )
    }

    // certificate is non-transferable but can be destroyed. need to think of safe-transfer logic to new address.
    public entry fun destroy_certificate(certificate: Certificate) {
        let Certificate {id, name: _, year: _} = certificate;
        object::delete(id);
    }

    public entry fun give_permission_verify_certificate(certificate: &Certificate, recipient: address, ctx: &mut TxContext) { 
        transfer::transfer(
            Permission<Certificate> {
            id: object::new(ctx),
            certificate_id: typed_id::new(certificate),
        },
            recipient
        )
    }

    public entry fun give_permission_verify_name(certificate: &Certificate, recipient: address, ctx: &mut TxContext) { 
        transfer::transfer(
            Permission<string::String> {
            id: object::new(ctx),
            certificate_id: typed_id::new(certificate),
        },
            recipient
        )
    }

    public entry fun give_permission_verify_year(certificate: &Certificate, recipient: address, ctx: &mut TxContext) { 
        transfer::transfer(
            Permission<u8> {
            id: object::new(ctx),
            certificate_id: typed_id::new(certificate),
        },
            recipient
        )
    }
                                        // OWNER A owns certificate  // OWNER B owns permission
    public entry fun verify_certificate(certificate: &Certificate, permission: Permission<Certificate>, _ctx: &mut TxContext) {
        assert!(typed_id::equals_object(&permission.certificate_id, certificate), ENoPermissionToVerify);
        let Permission { id, certificate_id: _,} = permission;
        object::delete(id);
    } // intent is to make OWNER B

    public entry fun verify_name(certificate: &Certificate, permission: Permission<string::String>, name: vector<u8>, _ctx: &mut TxContext) {
        assert!(typed_id::equals_object(&permission.certificate_id, certificate), ENoPermissionToVerify);
        let name = string::utf8(name);
        assert!(name==certificate.name, ENameIsIncorrect);
        let Permission { id, certificate_id: _,} = permission;
        object::delete(id);
    }

    public entry fun verify_year(certificate: &Certificate, permission: Permission<u8>, year: u128, _ctx: &mut TxContext) {
        assert!(typed_id::equals_object(&permission.certificate_id, certificate), ENoPermissionToVerify);
        assert!(year==certificate.year, EYearIsIncorrect);
        let Permission { id, certificate_id: _,} = permission;
        object::delete(id);
    }
}