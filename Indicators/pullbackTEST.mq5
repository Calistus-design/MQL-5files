//+------------------------------------------------------------------+
//|                                     Trendline_Retest_Signal.mq5  |
//|                          Built based on user-defined strategy    |
//|                                  (FINAL VERSION 1.19)            |
//+------------------------------------------------------------------+

#property copyright "User/Developer"
#property link      " "
#property version   "1.19"
#property indicator_chart_window
#property indicator_buffers 1 
#property indicator_plots   1

//--- Plot for the final BUY Arrow
#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Indicator Buffer
double BuySignalBuffer[];

//--- User Inputs
input int               MA_Period         = 10;
input ENUM_APPLIED_PRICE MA_Price          = PRICE_CLOSE;
input double            Hotspot_Pips      = 10.5;
input double            Max_Candle_Pips   = 20.0;
input int               Swing_Lookback    = 3;
input int               Search_History    = 200;

//--- Global Variables & Prototypes
int    ma_handle;
double hotspot_distance_in_price;
double max_candle_distance_in_price;
bool isSwingHigh(int index, const double &high[]);
double GetTrendlineValue(int for_index, int indexA, double priceA, int indexB, double priceB);

//+------------------------------------------------------------------+
//| OnInit, OnDeinit Functions (remain the same)                     |
//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, BuySignalBuffer, INDICATOR_DATA);
    PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up Arrow
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    
    ma_handle = iMA(_Symbol, _Period, MA_Period, 0, MODE_SMA, MA_Price);
    if(ma_handle == INVALID_HANDLE) { return(INIT_FAILED); }
    
    double pip_value = (_Digits == 3 || _Digits == 5) ? 10 * _Point : _Point;
    hotspot_distance_in_price = Hotspot_Pips * pip_value;
    max_candle_distance_in_price = Max_Candle_Pips * pip_value;

    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    if(ma_handle != INVALID_HANDLE) IndicatorRelease(ma_handle);
    ObjectsDeleteAll(0, "Signal_TL_"); 
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
    int bars_to_calculate = rates_total - prev_calculated;
    if(prev_calculated > 0) bars_to_calculate++;
    
    int copy_start_pos = prev_calculated > 0 ? prev_calculated - 1 : 0;
    
    double ma_values[];
    if(CopyBuffer(ma_handle, 0, copy_start_pos, bars_to_calculate, ma_values) <= 0) { return(prev_calculated); }

    for(int i = copy_start_pos, j = 0; i < rates_total; i++, j++)
    {
        BuySignalBuffer[i] = EMPTY_VALUE;

        if (j == 0 || i < Search_History) continue;

        double current_ma_value = ma_values[j];
        double previous_ma_value = ma_values[j-1];

        // Step 1 & 2: Find a qualified Candidate Candle
        bool isGreen = (close[i] > open[i]);
        bool isNearMA = (MathAbs(open[i] - current_ma_value) <= hotspot_distance_in_price);
        bool wasAbove = (high[i-1] > previous_ma_value);
        bool hasArrived = (low[i] <= current_ma_value);
        bool isPullback = (wasAbove && hasArrived);
        bool candleSizeOK = (MathAbs(close[i] - current_ma_value) <= max_candle_distance_in_price);
        
        if(isGreen && isNearMA && isPullback && candleSizeOK)
        {
            // Step 3: Find and Filter a Trendline
            int indexB = -1, indexA = -1;
            for(int k = i - 1; k > i - Search_History; k--)
            {
                if (isSwingHigh(k, high))
                {
                    if (indexB == -1) indexB = k; else { indexA = k; break; }
                }
            }

            if (indexA != -1 && indexB != -1 && high[indexA] > high[indexB])
            {
                bool isClean = true;
                for (int k = indexA + 1; k < indexB; k++)
                {
                    double tl_value = GetTrendlineValue(k, indexA, high[indexA], indexB, high[indexB]);
                    if (high[k] > tl_value) { isClean = false; break; }
                }

                if(isClean)
                {
                    double maA_val[], maB_val[];
                    if(CopyBuffer(ma_handle, 0, indexA, 1, maA_val) < 1) continue;
                    if(CopyBuffer(ma_handle, 0, indexB, 1, maB_val) < 1) continue;

                    if (high[indexA] > maA_val[0] && high[indexB] > maB_val[0])
                    {
                        bool breakout_confirmed = false;
                        for (int k = indexB + 1; k < i; k++)
                        {
                            double tl_value = GetTrendlineValue(k, indexA, high[indexA], indexB, high[indexB]);
                            double ma_k_val[];
                            if(CopyBuffer(ma_handle, 0, k, 1, ma_k_val) < 1) continue;
                            if (close[k] > tl_value && close[k] > ma_k_val[0])
                            {
                                breakout_confirmed = true;
                                break;
                            }
                        }

                        if(breakout_confirmed)
                        {
                            // --- NEW: THE FINAL RETEST CONFIRMATION ---
                            double retest_tl_value = GetTrendlineValue(i, indexA, high[indexA], indexB, high[indexB]);
                            
                            bool retest_ok = false;
                            double retest_point = EMPTY_VALUE;

                            // Attempt #1 (Wick)
                            if (MathAbs(low[i] - retest_tl_value) <= hotspot_distance_in_price)
                            {
                                retest_ok = true;
                                retest_point = low[i];
                            }
                            // Attempt #2 (Body)
                            else if (MathAbs(open[i] - retest_tl_value) <= hotspot_distance_in_price)
                            {
                                retest_ok = true;
                                retest_point = open[i];
                            }

                            if (retest_ok)
                            {
                                // --- ALL CONDITIONS MET: GENERATE SIGNAL ---
                                BuySignalBuffer[i] = low[i] - _Point * 15;
                                
                                string obj_name = "Signal_TL_" + TimeToString(time[i]);
                                ObjectCreate(0, obj_name, OBJ_TREND, 0, time[indexA], high[indexA], time[i], retest_point);
                                ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrAqua);
                                ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
                                ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);
                                ObjectSetInteger(0, obj_name, OBJPROP_RAY_RIGHT, false);
                            }
                        }
                    }
                }
            }
        }
    }
    return(rates_total);
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS (isSwingHigh, GetTrendlineValue)                |
//+------------------------------------------------------------------+
bool isSwingHigh(int index, const double &high[])
{
    if(index < Swing_Lookback || index > ArraySize(high) - Swing_Lookback - 1) return false;
    double center_high = high[index];
    for(int i = 1; i <= Swing_Lookback; i++)
    {
        if(high[index - i] >= center_high || high[index + i] > center_high) return false;
    }
    return true;
}

double GetTrendlineValue(int for_index, int indexA, double priceA, int indexB, double priceB)
{
    if (indexB == indexA) return priceA;
    return priceA + (double)(for_index - indexA) * (priceB - priceA) / (double)(indexB - indexA);
}