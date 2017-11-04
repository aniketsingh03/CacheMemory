/**********************************************************************/
/*   ____  ____                                                       */
/*  /   /\/   /                                                       */
/* /___/  \  /                                                        */
/* \   \   \/                                                       */
/*  \   \        Copyright (c) 2003-2009 Xilinx, Inc.                */
/*  /   /          All Right Reserved.                                 */
/* /---/   /\                                                         */
/* \   \  /  \                                                      */
/*  \___\/\___\                                                    */
/***********************************************************************/

#include "xsi.h"

struct XSI_INFO xsi_info;



int main(int argc, char **argv)
{
    xsi_init_design(argc, argv);
    xsi_register_info(&xsi_info);

    xsi_register_min_prec_unit(-12);
    work_m_13793183660614528674_2778229486_init();
    work_m_13793183660614528674_0977463664_init();
    work_m_13793183660614528674_1504793415_init();
    work_m_13793183660614528674_3328954585_init();
    work_m_02074381314966172647_1575487031_init();
    work_m_00022702446263397537_1294610885_init();
    work_m_16541823861846354283_2073120511_init();


    xsi_register_tops("work_m_00022702446263397537_1294610885");
    xsi_register_tops("work_m_16541823861846354283_2073120511");


    return xsi_run_simulation(argc, argv);

}
