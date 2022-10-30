module suicertification::certificates {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::string;
    use sui::typed_id::{Self, TypedID};
    use sui::table::{Self, Table};
    use sui::elliptic_curve::{Self as ec, RistrettoPoint};
    use std::option::{Self, Option};
    
    const ENoPermissionToVerify: u64 = 0;
    const ENoFieldInPermission: u64 = 1;
    const ENameIsIncorrect: u64 = 2;
    const EVerifyWhatInPermissionIsNotName: u64 = 3;
    const EYearIsIncorrect: u64 = 4;
    const ECertIDDoesNotMatch: u64 = 5;
    const EFailedCertificateVerification: u64 = 6;
    /// For when trying to destroy a non-zero balance.
    const ENonZero: u64 = 7;

    struct CertCreatorCap has key, store {
        id: UID,
    }

    struct Masked<phantom T: store + drop> has store, drop {
        commitment: RistrettoPoint, // Stores a Pedersen commitment to the value of the coin
        value: Option<string::String> // In the case that someone wants to open their value - this number will be public
    }
    
    // has no drop
    struct Certificate has key, store {
        id: UID,
        name: Masked<Name>,
        year: Masked<Year>,
        // can add a field `blinding_factor: <u8>` to reveal it or
        // transmit this info in real-life to permission holder
    }

    struct GrantPermissionsCap has key, store {
        id: UID,
        certificate_id: TypedID<Certificate>,
    }

    struct Permission<phantom T: store> has key {
        id: UID,
        certificate_id: TypedID<Certificate>, // TypedID has drop
    }

    struct Year has store, drop {} // has drop for easier dropping

    struct Name has store, drop {}

    fun init(ctx: &mut TxContext) {
        transfer::transfer(
            CertCreatorCap {
                id: object::new(ctx),
            },
            tx_context::sender(ctx)
        );
        transfer::share_object(
            table::new<TypedID<Certificate>, Certificate>(ctx),
        );
    }

    public fun create_and_set_value_for_masked<T: store + drop>(value: vector<u8>, blinding_factor: vector<u8>): Masked<T> {
        let commitment = ec::create_pedersen_commitment(
            ec::new_scalar_from_bytes(value),
            ec::new_scalar_from_bytes(blinding_factor)
        );

        let self = Masked<T> {
            commitment: commitment,
            value: option::none()
        };

        self
    }

    // allow recipient to request a certificate instead of issue it directly
    public entry fun issue_certificate(_: &CertCreatorCap,
        name_: vector<u8>,
        year_: vector<u8>,
        blinding_factor: vector<u8>, // issuer can choose to use a different blinding factor for each certificate
        certificates_table: &mut Table<TypedID<Certificate>, Certificate>,
        certificate_recipient: address,
        ctx: &mut TxContext
        ) {
            let masked_name = create_and_set_value_for_masked<Name>(name_, blinding_factor);
            let masked_year = create_and_set_value_for_masked<Year>(year_, blinding_factor);

            let certificate = Certificate {
                id: object::new(ctx),
                name: masked_name,
                year: masked_year,
            }; // make the certificate

            let certificate_id = typed_id::new(&certificate);
            table::add(certificates_table, certificate_id, certificate); // add the certificate to the table

            let grant_permissions_cap = GrantPermissionsCap {
                id: object::new(ctx),
                certificate_id: certificate_id,
            }; // make the capability for granting permissions

            transfer::transfer(
                grant_permissions_cap,
                certificate_recipient
            ) // transfer that capability
    }

    // certificate is non-transferable but can be destroyed. need to think of safe-transfer logic to new address.
    public entry fun destroy_certificate(certificate: Certificate, ctx: &mut TxContext) {
        let Certificate {id: id, name: _, year: _} = certificate;
        object::delete(id);
    }

    public entry fun destory_permission<T: store>(permission: Permission<T>, ctx: &mut TxContext) {
        let Permission {id: id, certificate_id: _,} = permission;
        object::delete(id);
    }

    fun destory_record_in_table(grant_permission: &GrantPermissionsCap, certificates_table: &mut Table<TypedID<Certificate>, Certificate>, ctx: &mut TxContext): () {
        let certificate_id = grant_permission.certificate_id;
        let certificate = table::borrow(certificates_table, certificate_id);
        assert!(typed_id::equals_object(&certificate_id, certificate), ECertIDDoesNotMatch); // just to be absolutely sure
        let cert_to_be_destroyed = table::remove(certificates_table, certificate_id);
        destroy_certificate(cert_to_be_destroyed, ctx);
    }

    public entry fun destory_grant_permission(grant_permission: GrantPermissionsCap,
        certificates_table: &mut Table<TypedID<Certificate>, Certificate>,
        ctx: &mut TxContext) {
        
        destory_record_in_table(&grant_permission, certificates_table, ctx);
        let GrantPermissionsCap {id: id, certificate_id:_,} = grant_permission;
        object::delete(id);
    }

    public entry fun give_permission_verify_certificate(grant_permission: &GrantPermissionsCap, recipient: address, ctx: &mut TxContext) { 
        transfer::transfer(
            Permission<Certificate> {
            id: object::new(ctx),
            certificate_id: grant_permission.certificate_id,
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
                                            // owned by 0xWantsToVerify         // owned by 0xAuth
    public entry fun verify_certificate(permission: Permission<Certificate>, certificates_table: &Table<TypedID<Certificate>, Certificate>, _ctx: &mut TxContext) {
        let Permission { id, certificate_id: certificate_id,} = permission;
        object::delete(id);
        let certificate_exists = table::contains(certificates_table, certificate_id);
        if (!certificate_exists) {
            abort EFailedCertificateVerification
        };
    }

    public entry fun verify_field<T: store>(permission: Permission<T>,
        field: vector<u8>,
        value: vector<u8>,
        blinding_factor: vector<u8>,
        certificates_table: &Table<TypedID<Certificate>, Certificate>,
        _ctx: &mut TxContext) {
        
        let Permission { id, certificate_id: certificate_id,} = permission;
        object::delete(id);

        let certificate_exists = table::contains(certificates_table, certificate_id);
        if (!certificate_exists) {
            abort EFailedCertificateVerification
        };

        if (field == b"name") {
            let certificate = table::borrow(certificates_table, certificate_id);
            let name_commitment = certificate.name.commitment;
            let to_be_verified_name_commitment = ec::create_pedersen_commitment(
                ec::new_scalar_from_bytes(value),
                ec::new_scalar_from_bytes(blinding_factor)
            );
            assert!(name_commitment == to_be_verified_name_commitment, ENameIsIncorrect)
        };
        if (field == b"year") {
            let certificate = table::borrow(certificates_table, certificate_id);
            let year_commitment = certificate.year.commitment;
            let to_be_verified_year_commitment = ec::create_pedersen_commitment(
                ec::new_scalar_from_bytes(value),
                ec::new_scalar_from_bytes(blinding_factor)
            );
            assert!(year_commitment == to_be_verified_year_commitment, ENameIsIncorrect)
        };
    }
}