//+------------------------------------------------------------------+
//| ChartSync.mq5 - Synchronize charts by time cursor position       |
//+------------------------------------------------------------------+
#property strict
#property version "1.01"

enum ENUM_SYNC_MODE
{
   MODE_MASTER, // Sends the time signal
   MODE_SLAVE   // Receives the signal and scrolls
};

input ENUM_SYNC_MODE Input_ChartMode = MODE_MASTER;

long lastSyncedTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   if (Input_ChartMode == MODE_SLAVE)
   {
      EventSetMillisecondTimer(200);
      Print("ChartSync SLAVE initialized on ", _Symbol, ". Listening for updates.");
   }
   else
   {
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 1);
      Print("ChartSync MASTER initialized on ", _Symbol, ". Ready to broadcast time.");
   }
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if (Input_ChartMode == MODE_SLAVE)
   {
      EventKillTimer();
      Print("ChartSync SLAVE deinitialized on ", _Symbol);
   }
   else
   {
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 0);
      Print("ChartSync MASTER deinitialized on ", _Symbol);
   }
}
//+------------------------------------------------------------------+
void OnTimer()
{
   if (Input_ChartMode != MODE_SLAVE)
      return;

   string gv_name = "ChartSync.Time." + _Symbol;
   if (!GlobalVariableCheck(gv_name))
      return;

   long newTime = (long)GlobalVariableGet(gv_name);

   if (newTime != 0 && newTime != lastSyncedTime)
   {
      int bar_index = iBarShift(_Symbol, _Period, (datetime)newTime, false);
      if (bar_index >= 0)
      {
         ChartNavigate(0, CHART_END, -bar_index);
         lastSyncedTime = newTime;
         ChartRedraw();
      }
   }
}
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if (Input_ChartMode != MODE_MASTER)
      return;

   if (id == CHARTEVENT_MOUSE_MOVE)
   {
      int sub_window;
      datetime time_of_candle;
      double price;

      if (ChartXYToTimePrice(0, (int)lparam, (int)dparam, sub_window, time_of_candle, price))
      {
         string gv_name = "ChartSync.Time." + _Symbol;
         GlobalVariableSet(gv_name, (double)time_of_candle);
      }
   }
}
//+------------------------------------------------------------------+
