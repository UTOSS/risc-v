`include "src/timescale.svh"
`include "src/headers/types.svh"
`include "src/ext/zknh/types.svh"

/* verilator lint_off DECLFILENAME */
module ext__zknh__logic
/* verilator lint_on DECLFILENAME */
  ( input  data_t a
  , input  data_t b
  , input  ext__zknh__types::zknh_control_t zknh_control
  , output data_t out
  , output logic  zeroE
  );

  import ext__zknh__types::*;

  localparam int XLEN = `PROCESSOR_BITNESS;

  function automatic data_t get_ror(input data_t val, input int shift_amount);
    get_ror = (val >> shift_amount) | (val << (XLEN - shift_amount));
  endfunction

  // sha256* only look at the first operand
  function automatic data_t get_sha256sum0(input data_t val);
    get_sha256sum0 = get_ror(val, 2) ^ get_ror(val, 13) ^ get_ror(val, 22);
  endfunction

  function automatic data_t get_sha256sum1(input data_t val);
    get_sha256sum1 = get_ror(val, 6) ^ get_ror(val, 11) ^ get_ror(val, 25);
  endfunction

  function automatic data_t get_sha256sig0(input data_t val);
    get_sha256sig0 = get_ror(val, 7) ^ get_ror(val, 18) ^ (val >> 3);
  endfunction

  function automatic data_t get_sha256sig1(input data_t val);
    get_sha256sig1 = get_ror(val, 17) ^ get_ror(val, 19) ^ (val >> 10);
  endfunction

  // on RV32 the sha512* ops take the low half in `a` and the high half in `b`;
  // l/h give the named half, r gives the low half
  function automatic data_t get_sha512sig0l(input data_t low, input data_t high);
    get_sha512sig0l = (low >> 1) ^ (low >> 7) ^ (low >> 8) ^ (high << 31) ^ (high << 25) ^ (high << 24);
  endfunction

  function automatic data_t get_sha512sig0h(input data_t low, input data_t high);
    get_sha512sig0h = (low >> 1) ^ (low >> 7) ^ (low >> 8) ^ (high << 31) ^ (high << 24);
  endfunction

  function automatic data_t get_sha512sig1l(input data_t low, input data_t high);
    get_sha512sig1l = (low << 3) ^ (low >> 6) ^ (low >> 19) ^ (high >> 29) ^ (high << 26) ^ (high << 13);
  endfunction

  function automatic data_t get_sha512sig1h(input data_t low, input data_t high);
    get_sha512sig1h = (low << 3) ^ (low >> 6) ^ (low >> 19) ^ (high >> 29) ^ (high << 13);
  endfunction

  function automatic data_t get_sha512sum0r(input data_t low, input data_t high);
    get_sha512sum0r = (low << 25) ^ (low << 30) ^ (low >> 28) ^ (high >> 7) ^ (high >> 2) ^ (high << 4);
  endfunction

  function automatic data_t get_sha512sum1r(input data_t low, input data_t high);
    get_sha512sum1r = (low << 23) ^ (low >> 14) ^ (low >> 18) ^ (high >> 9) ^ (high << 18) ^ (high << 14);
  endfunction

  always_comb
    case (zknh_control)
      ZKNH_CTRL__SHA256SUM0:  out = get_sha256sum0(a);
      ZKNH_CTRL__SHA256SUM1:  out = get_sha256sum1(a);
      ZKNH_CTRL__SHA256SIG0:  out = get_sha256sig0(a);
      ZKNH_CTRL__SHA256SIG1:  out = get_sha256sig1(a);
      ZKNH_CTRL__SHA512SUM0R: out = get_sha512sum0r(a, b);
      ZKNH_CTRL__SHA512SUM1R: out = get_sha512sum1r(a, b);
      ZKNH_CTRL__SHA512SIG0L: out = get_sha512sig0l(a, b);
      ZKNH_CTRL__SHA512SIG1L: out = get_sha512sig1l(a, b);
      ZKNH_CTRL__SHA512SIG0H: out = get_sha512sig0h(a, b);
      ZKNH_CTRL__SHA512SIG1H: out = get_sha512sig1h(a, b);
      default:                out = '0;
    endcase

  assign zeroE = (out == '0);

endmodule
