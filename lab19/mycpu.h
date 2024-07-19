`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD        37
    `define FS_TO_DS_BUS_WD  99
    `define DS_TO_ES_BUS_WD  200
    `define ES_TO_MS_BUS_WD  168
    `define MS_TO_WS_BUS_WD  128
    `define WS_TO_RF_BUS_WD  41
    `define ES_TO_RF_BUS_WD  40
    `define MS_TO_RF_BUS_WD  42
    `define WS_TO_CP0_BUS_WS 119

    `define CR_STATUS   12
    `define CR_CAUSE    13
    `define CR_COMPARE  11
    `define CR_COUNT    9
    `define CR_EPC      14
    `define CR_BADVADDR 8
    `define CR_INDEX    0
    `define CR_ENTRYLO0 2
    `define CR_ENTRYLO1 3
    `define CR_ENTRYHI  10
    `define CR_CONFIG   16
    
    `define TLB_NUM     16
    `define IDX_W       4

    `define EX_INT      0
    `define EX_MOD      1 
    `define EX_TLBL     2
    `define EX_TLBS     3
    `define EX_ADEL     4
    `define EX_ADES     5
`endif
