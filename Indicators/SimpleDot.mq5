//+------------------------------------------------------------------+
//|                                     Simple_MA_Proximity_Dot.mq5  |
//|                                (CORRECT DATA HANDLING - FINAL V2)  |
//+------------------------------------------------------------------+

#property copyright "User/Developer"
#property link      " "
#property version   "1.05_FIXED"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1

//--- Plot for the Dot
#property indicator_label1  "MA Proximity Dot"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrYellow
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Indicator Buffer
double DotBuffer[];

//--- User Inputs
input int               MA_Period         = 10;
input ENUM_APPLIED_PRICE MA_Price          = PRICE_CLOSE;
input double            Hotspot_Pips      = 5.0;

//--- Global Variables
int    ma_handle;
double hotspot_distance_in_price;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, DotBuffer, INDICATOR_DATA);
    PlotIndexSetInteger(0, PLOT_ARROW, 159);
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    
    ma_handle = iMA(_Symbol, _Period, MA_Period, 0, MODE_SMA, MA_Price);
    if(ma_handle == INVALID_HANDLE)
    {
        Print("Failed to create MA handle. Error: ", GetLastError());
        return(INIT_FAILED);
    }
    
    // --- Robust Pip Calculation ---
    double pip_value;
    if(_Digits == 3 || _Digits == 5)
        pip_value = 10 * _Point;
    else
        pip_value = _Point;
    
    hotspot_distance_in_price = Hotspot_Pips * pip_value;
    
    Print("Indicator Initialized. Hotspot Pips: ", Hotspot_Pips, " -> Price Distance: ", hotspot_distance_in_price);

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(ma_handle != INVALID_HANDLE)
        IndicatorRelease(ma_handle);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &real_volume[],
                const int &spread[])
{
    // --- THIS IS THE CORRECTED DATA HANDLING LOGIC ---

    // 1. Determine how many bars we need to calculate
    int bars_to_calculate = rates_total - prev_calculated;
    if(prev_calculated > 0)
        bars_to_calculate++; // Add one bar to overlap and ensure data is current
    
    // Define the starting position for copying data
    int copy_start_pos = prev_calculated > 0 ? prev_calculated - 1 : 0;
    
    // 2. Create an array to hold the MA values
    double ma_values[];
    
    // 3. Copy ALL the necessary MA data in ONE operation
    if(CopyBuffer(ma_handle, 0, copy_start_pos, bars_to_calculate, ma_values) <= 0)
    {
        // If copy fails, print an error and wait for the next tick
        Print("Could not copy MA data. Error: ", GetLastError());
        return(prev_calculated); // Return prev_calculated so we try again next time
    }

    // 4. Now, loop through the bars we have data for
    //    We map the index 'i' from our loop to the index 'j' of our ma_values array
    for(int i = copy_start_pos, j = 0; i < rates_total; i++, j++)
    {
        // Set default to no dot
        DotBuffer[i] = EMPTY_VALUE;

        // Condition 1: Is the candle green?
        bool isGreen = (close[i] > open[i]);
        
        // Get the MA value from our LOCAL array. This is reliable and fast.
        double current_ma_value = ma_values[j];
        
        // Condition 2: Is the open price near the MA?
        double actual_distance = MathAbs(open[i] - current_ma_value);
        bool isNearMA = (actual_distance <= hotspot_distance_in_price);
        
        // If BOTH conditions are true, place the dot
        if(isGreen && isNearMA)
        {
            DotBuffer[i] = high[i] + _Point * 10;
        }
    }
    return(rates_total);
}
//+------------------------------------------------------------------+