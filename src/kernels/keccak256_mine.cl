/*
 * keccak256_mine.cl  (optimized)
 *
 * Key optimizations vs original:
 *  1. Precompute state lanes 0-6 (challenge+prefix are fixed) outside inner loop.
 *  2. Each work-item scans NONCES_PER_ITEM nonces — reduces kernel-launch overhead.
 *  3. Early-exit uint32-word comparison — no need to materialise a hash[] byte array.
 *  4. bswap + direct lane loading — no intermediate input[64] byte array on the stack.
 *
 * Protocol (unchanged):
 *   message = challenge(32) || nonce_prefix(24) || uint64_be(nonce)
 *   hash    = keccak256(message)   [Keccak padding 0x01, NOT SHA3 0x06]
 *   hit     = hash < difficulty    (big-endian uint256 compare)
 */

#ifndef NONCES_PER_ITEM
#define NONCES_PER_ITEM 64UL
#endif

/* ── Keccak-f[1600] round constants ─────────────────────────────────────── */
__constant ulong RC[24] = {
    0x0000000000000001UL, 0x0000000000008082UL, 0x800000000000808aUL,
    0x8000000080008000UL, 0x000000000000808bUL, 0x0000000080000001UL,
    0x8000000080008081UL, 0x8000000000008009UL, 0x000000000000008aUL,
    0x0000000000000088UL, 0x0000000080008009UL, 0x000000008000000aUL,
    0x000000008000808bUL, 0x800000000000008bUL, 0x8000000000008089UL,
    0x8000000000008003UL, 0x8000000000008002UL, 0x8000000000000080UL,
    0x000000000000800aUL, 0x800000008000000aUL, 0x8000000080008081UL,
    0x8000000000008080UL, 0x0000000080000001UL, 0x8000000080008008UL,
};

#define ROTL64(x, n) (((x) << (n)) | ((x) >> (64u - (n))))

/* ── Byte-swap helpers ───────────────────────────────────────────────────── */
inline uint bswap32(uint v) {
    return ((v & 0x000000FFu) << 24) | ((v & 0x0000FF00u) <<  8) |
           ((v & 0x00FF0000u) >>  8) | ((v & 0xFF000000u) >> 24);
}

/* Load 8 bytes as a little-endian uint64 lane */
inline ulong load_le64(__constant const uchar *p) {
    return (ulong)p[0]        | ((ulong)p[1] <<  8) | ((ulong)p[2] << 16) |
           ((ulong)p[3] << 24) | ((ulong)p[4] << 32) | ((ulong)p[5] << 40) |
           ((ulong)p[6] << 48) | ((ulong)p[7] << 56);
}

/* Encode a uint64 counter as big-endian bytes → little-endian lane (= bswap64) */
inline ulong nonce_to_lane(ulong v) {
    return ((v & 0x00000000000000FFUL) << 56) | ((v & 0x000000000000FF00UL) << 40) |
           ((v & 0x0000000000FF0000UL) << 24) | ((v & 0x00000000FF000000UL) <<  8) |
           ((v & 0x000000FF00000000UL) >>  8) | ((v & 0x0000FF0000000000UL) >> 24) |
           ((v & 0x00FF000000000000UL) >> 40) | ((v & 0xFF00000000000000UL) >> 56);
}

/* ── Keccak-f[1600] permutation (fully unrolled by compiler) ─────────────── */
void keccak_f1600(ulong *st) {
    ulong C0, C1, C2, C3, C4;
    ulong D0, D1, D2, D3, D4;
    ulong B00, B01, B02, B03, B04;
    ulong B05, B06, B07, B08, B09;
    ulong B10, B11, B12, B13, B14;
    ulong B15, B16, B17, B18, B19;
    ulong B20, B21, B22, B23, B24;

    for (int r = 0; r < 24; r++) {
        /* θ */
        C0 = st[ 0] ^ st[ 5] ^ st[10] ^ st[15] ^ st[20];
        C1 = st[ 1] ^ st[ 6] ^ st[11] ^ st[16] ^ st[21];
        C2 = st[ 2] ^ st[ 7] ^ st[12] ^ st[17] ^ st[22];
        C3 = st[ 3] ^ st[ 8] ^ st[13] ^ st[18] ^ st[23];
        C4 = st[ 4] ^ st[ 9] ^ st[14] ^ st[19] ^ st[24];

        D0 = C4 ^ ROTL64(C1, 1);
        D1 = C0 ^ ROTL64(C2, 1);
        D2 = C1 ^ ROTL64(C3, 1);
        D3 = C2 ^ ROTL64(C4, 1);
        D4 = C3 ^ ROTL64(C0, 1);

        st[ 0] ^= D0; st[ 5] ^= D0; st[10] ^= D0; st[15] ^= D0; st[20] ^= D0;
        st[ 1] ^= D1; st[ 6] ^= D1; st[11] ^= D1; st[16] ^= D1; st[21] ^= D1;
        st[ 2] ^= D2; st[ 7] ^= D2; st[12] ^= D2; st[17] ^= D2; st[22] ^= D2;
        st[ 3] ^= D3; st[ 8] ^= D3; st[13] ^= D3; st[18] ^= D3; st[23] ^= D3;
        st[ 4] ^= D4; st[ 9] ^= D4; st[14] ^= D4; st[19] ^= D4; st[24] ^= D4;

        /* ρ + π */
        B00 =            st[ 0];
        B10 = ROTL64(st[ 1],  1); B20 = ROTL64(st[ 2], 62);
        B05 = ROTL64(st[ 3], 28); B15 = ROTL64(st[ 4], 27);
        B16 = ROTL64(st[ 5], 36); B01 = ROTL64(st[ 6], 44);
        B11 = ROTL64(st[ 7],  6); B21 = ROTL64(st[ 8], 55);
        B06 = ROTL64(st[ 9], 20); B07 = ROTL64(st[10],  3);
        B17 = ROTL64(st[11], 10); B02 = ROTL64(st[12], 43);
        B12 = ROTL64(st[13], 25); B22 = ROTL64(st[14], 39);
        B23 = ROTL64(st[15], 41); B08 = ROTL64(st[16], 45);
        B18 = ROTL64(st[17], 15); B03 = ROTL64(st[18], 21);
        B13 = ROTL64(st[19],  8); B14 = ROTL64(st[20], 18);
        B24 = ROTL64(st[21],  2); B09 = ROTL64(st[22], 61);
        B19 = ROTL64(st[23], 56); B04 = ROTL64(st[24], 14);

        /* χ */
        st[ 0] = B00 ^ (~B01 & B02); st[ 1] = B01 ^ (~B02 & B03);
        st[ 2] = B02 ^ (~B03 & B04); st[ 3] = B03 ^ (~B04 & B00);
        st[ 4] = B04 ^ (~B00 & B01);
        st[ 5] = B05 ^ (~B06 & B07); st[ 6] = B06 ^ (~B07 & B08);
        st[ 7] = B07 ^ (~B08 & B09); st[ 8] = B08 ^ (~B09 & B05);
        st[ 9] = B09 ^ (~B05 & B06);
        st[10] = B10 ^ (~B11 & B12); st[11] = B11 ^ (~B12 & B13);
        st[12] = B12 ^ (~B13 & B14); st[13] = B13 ^ (~B14 & B10);
        st[14] = B14 ^ (~B10 & B11);
        st[15] = B15 ^ (~B16 & B17); st[16] = B16 ^ (~B17 & B18);
        st[17] = B17 ^ (~B18 & B19); st[18] = B18 ^ (~B19 & B15);
        st[19] = B19 ^ (~B15 & B16);
        st[20] = B20 ^ (~B21 & B22); st[21] = B21 ^ (~B22 & B23);
        st[22] = B22 ^ (~B23 & B24); st[23] = B23 ^ (~B24 & B20);
        st[24] = B24 ^ (~B20 & B21);

        /* ι */
        st[0] ^= RC[r];
    }
}

/*
 * Early-exit big-endian uint256 compare: digest(st) < difficulty ?
 * Compares 8 big-endian uint32 words derived from Keccak lanes without
 * materialising a hash[] byte array.
 *
 * Keccak lane storage is little-endian:
 *   hash_byte[n] = (st[n/8] >> (8*(n%8))) & 0xFF
 * Big-endian word 0 = bswap32( (uint)(st[0]) )
 * Big-endian word 1 = bswap32( (uint)(st[0] >> 32) )
 * ... etc for st[1] lo/hi, st[2] lo/hi, st[3] lo/hi
 */
inline int digest_lt(__constant const uchar *diff, const ulong *st) {
    uint h, d;
#define CMP_WORD(lane, shift, di)                                              \
    h = bswap32((uint)((st[lane] >> (shift)) & 0xFFFFFFFFUL));                 \
    d = ((uint)diff[(di)*4]   << 24) | ((uint)diff[(di)*4+1] << 16) |         \
        ((uint)diff[(di)*4+2] <<  8) |  (uint)diff[(di)*4+3];                 \
    if (h != d) return (int)(h < d);

    CMP_WORD(0,  0, 0)
    CMP_WORD(0, 32, 1)
    CMP_WORD(1,  0, 2)
    CMP_WORD(1, 32, 3)
    CMP_WORD(2,  0, 4)
    CMP_WORD(2, 32, 5)
    CMP_WORD(3,  0, 6)
    CMP_WORD(3, 32, 7)
#undef CMP_WORD
    return 0; /* equal → not less than */
}

/* ── Main mining kernel ─────────────────────────────────────────────────── */
__kernel void mine(
    __constant uchar *challenge,    /* 32 bytes */
    __constant uchar *difficulty,   /* 32 bytes, big-endian uint256 target */
    __constant uchar *nonce_prefix, /* 24 bytes */
    ulong             base_counter, /* starting counter for this batch */
    __global   int   *found_flag,   /* output: set to 1 on hit */
    __global   ulong *found_counter /* output: winning counter value */
) {
    ulong tid      = (ulong)get_global_id(0);
    ulong my_base  = base_counter + tid * NONCES_PER_ITEM;

    /*
     * Precompute state lanes 0-6 from the FIXED part of the message
     * (challenge[0..31] and nonce_prefix[0..23]).
     * These 56 bytes map directly to 7 little-endian uint64 lanes.
     * Only lane 7 changes per nonce (the 8-byte big-endian counter).
     */
    ulong s0 = load_le64(challenge + 0);
    ulong s1 = load_le64(challenge + 8);
    ulong s2 = load_le64(challenge + 16);
    ulong s3 = load_le64(challenge + 24);
    ulong s4 = load_le64(nonce_prefix + 0);
    ulong s5 = load_le64(nonce_prefix + 8);
    ulong s6 = load_le64(nonce_prefix + 16);

    for (ulong k = 0; k < NONCES_PER_ITEM; k++) {
        ulong nonce = my_base + k;

        ulong st[25];
        for (int i = 0; i < 25; i++) st[i] = 0UL;

        /* Load fixed lanes */
        st[0] = s0; st[1] = s1; st[2] = s2; st[3] = s3;
        st[4] = s4; st[5] = s5; st[6] = s6;

        /* Lane 7: nonce encoded big-endian → little-endian lane */
        st[7] = nonce_to_lane(nonce);

        /* Keccak padding (rate=136, message=64 bytes) */
        st[ 8] = 0x0000000000000001UL;
        st[16] = 0x8000000000000000UL;

        keccak_f1600(st);

        if (digest_lt(difficulty, st)) {
            /* atomic_cmpxchg guards against duplicate writes from two work-items */
            if (atomic_cmpxchg((volatile __global int *)found_flag, 0, 1) == 0) {
                *found_counter = nonce;
            }
            return; /* early exit — no need to try more nonces */
        }
    }
}
