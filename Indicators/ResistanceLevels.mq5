//+------------------------------------------------------------------+
//|                                     ImpulseResistanceZones.mq5 |
//|                                                      Copyright 2025 |
//|                                                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "3.00" // New version using Rectangles (Zones)
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Indicator Inputs ---
input int  LookbackPeriod   = 300;     // Number of candles to analyze for pivots
input int  ATR_Period       = 14;      // Period for the ATR calculation
input double ATR_Multiplier = 1.5;     // How many times ATR price must drop to confirm a zone
input int  ImpulseLookback  = 10;      // How many candles to wait for the impulse move

//--- Zone Visuals ---
input color ZoneColor       = clrMaroon; // Color of the resistance zones
input bool  FillZone        = true;      // Fill the rectangle with color?

//--- Global Variables ---
string ObjectPrefix = "ImpulseZone_"; // Unique prefix for our rectangle objects
int    AtrHandle; // Handle for the ATR indicator

//+------------------------------------------------------------------+
int OnInit()
  {
   AtrHandle = iATR(_Symbol, _Period, ATR_Period);
   if(AtrHandle == INVALID_HANDLE)
     {
      Print("Error creating ATR indicator handle");
      return(INIT_FAILED);
     }
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, ObjectPrefix);
   IndicatorRelease(AtrHandle);
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   // On every new bar, redraw everything for dynamic invalidation
   ObjectsDeleteAll(0, ObjectPrefix);
   
   // Determine the starting bar for our loop.
   int startBar = rates_total - LookbackPeriod;
   if(startBar < 1) startBar = 1;

   //--- Loop backwards through historical bars to find pivots
   for(int pivotIndex = rates_total - 2; pivotIndex >= startBar; pivotIndex--)
     {
      //--- ### STEP 1: IDENTIFY A POTENTIAL PIVOT ### ---
      if(high[pivotIndex] > high[pivotIndex+1] && high[pivotIndex] > high[pivotIndex-1])
        {
         //--- ### STEP 2: CONFIRM PIVOT WITH AN IMPULSE MOVE ### ---
         double atrValueArr[1];
         if(CopyBuffer(AtrHandle, 0, pivotIndex, 1, atrValueArr) <= 0) continue;
         
         double pivotHigh = high[pivotIndex];
         double requiredDrop = atrValueArr[0] * ATR_Multiplier;
         bool isConfirmed = false;
         
         // Loop forward from the pivot to see if the price drops enough
         for(int k = pivotIndex + 1; k < pivotIndex + ImpulseLookback && k < rates_total; k++)
           {
            if(pivotHigh - low[k] >= requiredDrop)
              {
               isConfirmed = true;
               break;
              }
           }
           
         //--- ### STEP 3: IF CONFIRMED, FIND ZONE ENDPOINT & DRAW ### ---
         if(isConfirmed)
           {
            // Define the Zone's price levels
            double zoneTop = pivotHigh;
            double zoneBottom = close[pivotIndex]; // Top of the pivot candle's body
            
            // Find when the zone was broken (or if it's still active)
            datetime endTime = time[rates_total-1] + (PeriodSeconds()*10); // Default to future if not broken
            
            // Loop forward from pivot to find the breakout candle
            for(int k = pivotIndex + 1; k < rates_total; k++)
              {
               // If a candle closes above the zone, it's broken.
               if(close[k] > zoneTop)
                 {
                  endTime = time[k]; // The zone ends at the time of the breakout
                  break;
                 }
              }

            // Draw the rectangle
            string objectName = StringFormat("%s%d", ObjectPrefix, time[pivotIndex]);
            ObjectCreate(0, objectName, OBJ_RECTANGLE, 0, time[pivotIndex], zoneTop, endTime, zoneBottom);
            ObjectSetInteger(0, objectName, OBJPROP_COLOR, ZoneColor);
            ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, objectName, OBJPROP_BACK, true); // Draw behind the candles
            ObjectSetInteger(0, objectName, OBJPROP_FILL, FillZone);
            
            // To improve performance, skip checking inner candles of the same zone
            // by moving the main loop index past this confirmed area.
            int lastPiv = pivotIndex - ImpulseLookback;
            if (lastPiv > startBar) pivotIndex = lastPiv;
           }
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+