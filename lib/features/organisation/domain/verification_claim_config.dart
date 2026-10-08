enum ClaimFieldType { text, number, dropdown }

class ClaimField {
  const ClaimField({required this.key, required this.label, required this.type, this.options});

  final String key;
  final String label;
  final ClaimFieldType type;
  final List<String>? options;
}

/// What the organisation worker types in for a given credential type --
/// the applicant's claim, taken from whatever the organisation's own
/// external application/onboarding process already collected (e.g. "if I
/// work at Spar, the applicant's Spar application says..."). Stored as
/// `verification_results.claimed_value` at request time; `complete_verification`
/// (docs/database/automated_verification_and_org_revocation.sql) later
/// compares this, field by field, against the real department record.
///
/// Fields deliberately mirror the columns the authoritative department
/// table actually has (same enum values, confirmed against the live
/// schema) so the automated comparison is an honest exact-field match, not
/// a fuzzy free-text guess.
List<ClaimField> claimFieldsForType(String typeCode) => switch (typeCode) {
      'NSC' => [
          const ClaimField(
            key: 'overall_pass_status',
            label: 'Claimed matric pass status',
            type: ClaimFieldType.dropdown,
            options: ['Bachelor Pass', 'Diploma', 'Higher Certificate'],
          ),
          ClaimField(
            key: 'year',
            label: 'Claimed matric year',
            type: ClaimFieldType.dropdown,
            options: _matricYears(),
          ),
        ],
      'TERTIARY_QUALIFICATION' => const [
          ClaimField(key: 'qualification_name', label: 'Claimed qualification', type: ClaimFieldType.text),
          ClaimField(
            key: 'institution_code',
            label: 'Claimed institution',
            type: ClaimFieldType.dropdown,
            options: [
              'UCT',
              'UKZN',
              'UP',
              'WITS',
              'NMU',
              'SU',
              'CPUT TVET',
              'False Bay TVET',
              'Tshwane North TVET',
            ],
          ),
          ClaimField(
            key: 'result_status',
            label: 'Claimed result/status (e.g. Pass, Graduated, Enrolled)',
            type: ClaimFieldType.text,
          ),
        ],
      'DRIVERS_LICENCE' => const [
          ClaimField(key: 'licence_code', label: 'Claimed licence code (e.g. B)', type: ClaimFieldType.text),
          ClaimField(
            key: 'status',
            label: 'Claimed status',
            type: ClaimFieldType.dropdown,
            options: ['Valid', 'Suspended', 'Expired'],
          ),
        ],
      'PASSPORT' => const [
          ClaimField(
            key: 'status',
            label: 'Claimed status',
            type: ClaimFieldType.dropdown,
            options: ['Active', 'Expired', 'Revoked'],
          ),
        ],
      'TAX_COMPLIANCE' => const [
          ClaimField(
            key: 'tax_compliance_status',
            label: 'Claimed tax compliance status',
            type: ClaimFieldType.dropdown,
            options: ['Compliant', 'Non-Compliant'],
          ),
        ],
      'CRIMINAL_CLEARANCE' => const [
          ClaimField(
            key: 'status',
            label: 'Claimed clearance status',
            type: ClaimFieldType.dropdown,
            options: ['Clear', 'Record Found'],
          ),
        ],
      'LABOUR_STATUS' => const [
          ClaimField(
            key: 'employment_status',
            label: 'Claimed employment status',
            type: ClaimFieldType.dropdown,
            options: ['Employed', 'Unemployed', 'Self-Employed'],
          ),
        ],
      'SASSA_STATUS' => const [
          ClaimField(
            key: 'grant_type',
            label: 'Claimed grant type',
            type: ClaimFieldType.dropdown,
            options: ['SRD R370', 'Child Support', 'Disability', 'Old Age'],
          ),
          ClaimField(
            key: 'status',
            label: 'Claimed grant status',
            type: ClaimFieldType.dropdown,
            options: ['Active', 'Pending', 'Suspended'],
          ),
        ],
      _ => const [],
    };

/// Most recent first, back to 1970 -- picked rather than typed so the claim
/// is always a well-formed year.
List<String> _matricYears() => [for (var y = DateTime.now().year; y >= 1970; y--) '$y'];
