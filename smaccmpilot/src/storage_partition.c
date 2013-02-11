/* This file has been autogenerated by Ivory
 * Compiler version  0.1.0.0
 */
#include "storage_partition.h"
uint16_t partition_size(int32_t n_var0)
{
    uint16_t* n_ref0 = g_partition_table;
    uint16_t n_deref1 = *&n_ref0[n_var0];
    
    return n_deref1;
}
uint16_t partition_start(int32_t n_var0)
{
    uint16_t* n_ref0 = g_partition_table;
    uint16_t n_local1 = 0U;
    uint16_t* n_ref2 = &n_local1;
    
    for (int32_t n_ix3 = 0; n_ix3 <= (n_var0 - 1) % 3; n_ix3 = n_ix3 + 1) {
        uint16_t n_deref4 = *&n_ref0[n_ix3];
        uint16_t n_deref5 = *n_ref2;
        
        *n_ref2 = n_deref5 + n_deref4;
    }
    
    uint16_t n_deref6 = *n_ref2;
    
    return n_deref6;
}
bool partition_in_bounds(int32_t n_var0, uint16_t n_var1, uint16_t n_var2)
{
    uint16_t n_r0 = partition_size(n_var0);
    uint16_t n_let1 = n_var1 + n_var2;
    
    return n_let1 < n_r0;
}
bool partition_read(int32_t n_var0, uint16_t n_var1, uint8_t* n_var2,
                    uint16_t n_var3)
{
    bool n_r0 = partition_in_bounds(n_var0, n_var1, 0U);
    bool n_r1 = partition_in_bounds(n_var0, n_var1, n_var3);
    
    if (!(n_r0 && n_r1)) {
        return false;
    } else { }
    
    uint16_t n_r2 = partition_start(n_var0);
    bool n_r3 = eeprom_read(n_var1 + n_r2, n_var2, (uint32_t) n_var3);
    
    return n_r3;
}
bool partition_write(int32_t n_var0, uint16_t n_var1, const uint8_t* n_var2,
                     uint16_t n_var3)
{
    bool n_r0 = partition_in_bounds(n_var0, n_var1, 0U);
    bool n_r1 = partition_in_bounds(n_var0, n_var1, n_var3);
    
    if (!(n_r0 && n_r1)) {
        return false;
    } else { }
    
    uint16_t n_r2 = partition_start(n_var0);
    bool n_r3 = eeprom_write(n_var1 + n_r2, n_var2, (uint32_t) n_var3);
    
    return n_r3;
}
uint16_t g_partition_table[3U] = {0U, 4096U, 4096U};