`ifndef MYCPU_H
    `define MYCPU_H

    `define BR_BUS_WD        34
    `define FS_TO_DS_BUS_WD  97
    `define DS_TO_ES_BUS_WD  191
    `define ES_TO_MS_BUS_WD  154
    `define MS_TO_WS_BUS_WD  115
    `define WS_TO_RF_BUS_WD  41
    `define ES_TO_RF_BUS_WD  40
    `define MS_TO_RF_BUS_WD  42
    `define WS_TO_CP0_BUS_WS 111

    `define CR_STATUS   12
    `define CR_CAUSE    13
    `define CR_COMPARE  11
    `define CR_COUNT    9
    `define CR_EPC      14
    `define CR_BADVADDR 8

    `define EX_ADEL     4
    `define EX_ADES     5
`endif
