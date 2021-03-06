//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2012, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property description  "Name: piptrader.mq4"
#property description  ""
#property description  ""
#property description  ""
#property description  ""

#property copyright "Thorsten Stratmann"
#property version   "101.102"
#property link "https://github.com/thorsten3003/mql4"



//---------- Allgemeine Einstellungen ----------
input int Magic=101102;       // Magic number
input bool debug=true;
input double Lot = 0.01;         // feste Lotangabe wenn AutoLots=False
input double SpreadAbstandToOrder = 1;
input int Slippage = 3;         // Orderausf�hrung nur wenn Maximum price slippage kleiner ist
input int MaxOrders = 1;        // How many orders script can open on current symbol
input bool OpenNurbeiNeuemBar=false; // Sollen nur Orders bei neuem Bar ge�ffnet werden?
input int BuySellBeides = 3; // Welche Order ist erlaubt Buy=1, Sell=2, Beides=3

int Ticket;                     // Variable f�r die aktuell ausgew�hlte Order
double spread;                  // MarketInfo(Symbol(),MODE_SPREAD);      Abstand des Haendlers zw. bid und ask
double Min_Dist;                // MarketInfo(Symbol(),MODE_STOPLEVEL);   Min. distance zw. bid/ask und SL bzw. TP
datetime prevtime;              // Hilft zur Erkennung ob ein neuer Bar angefangen hat
bool neuerBAR=true;             // Zeigt bei TRUE an das ein neuer Bar angefangen hat
double modspread;               //
int Nachkommastellen;           // Digits,   MarketInfo(Symbol(),MODE_DIGITS);
double SLPips;                  // Berechneter Abstand in Pips aus dem maximalen Risiko des Money Managements
double Lots;                    // Dieser Lotwert pro Order eingesetzt
double pp;                      // Point, MarketInfo(Symbol(),MODE_POINT);
double StopLoss=0;          //Stop loss level,    Ask - ( StopLoss * Point )
double TakeProfit=0;        // Take profit level, Ask + ( TakeProfit * Point )


bool bar0=true;           // bei true wird erster SL auf Bar0 gelegt, sonst Bar1
double HighKurs=0.00;
double LowKurs=0.00;
int schleifenzaehler=0;

//+-----------------
input int anzahlKurse=3;     // Soviel Kurse werden zur berechnung benutzt
double bidKurs[];
double askKurs[];
double Kaufkurs;
double lastTickBid, lastTickAsk;
//+------------------------------------------------------------------+
//|             20 /10 *Nachkommastellen                                                     |
//+------------------------------------------------------------------+
void OnTick()
{


MqlTick last_tick;

   if(SymbolInfoTick(Symbol(),last_tick))
     {
      lastTickBid = last_tick.bid;
      lastTickAsk = last_tick.ask;
      
     }

 Lots=Lot;
 ArrayResize(bidKurs, anzahlKurse);
 ArrayResize(askKurs, anzahlKurse);


 Nachkommastellen=MarketInfo(Symbol(),MODE_DIGITS);
   spread=MarketInfo(Symbol(),MODE_SPREAD);     // Abstand des Haendler zw. bid und ask
   modspread= spread /10 * Nachkommastellen;
   Min_Dist=MarketInfo(Symbol(),MODE_STOPLEVEL);  //Min. distance zw. bid/ask und SL bzw. TP
   Min_Dist=NormalizeDouble((Min_Dist*Point),Digits);
   int AnzahlOrderOnSymbol=0;
   pp=MarketInfo(Symbol(),MODE_POINT);

//----------------------Tick Arrays Fuellen  --------------------------------

   for(int i=anzahlKurse-1; i>0; i--)
   {
    bidKurs[i] = bidKurs[i-1];
    askKurs[i] = askKurs[i-1];
  }
  bidKurs[0] = lastTickBid;
  askKurs[0] = lastTickAsk;

   infoAnzeigen();
   neuerBAR=isneuerBar();      // bestimmt ob neuer Bar beginnt

   for(int n=0; n<OrdersTotal(); n++)
   {
      // That loop search if there is opened order on current symbol.
    if(OrderSelect(n,SELECT_BY_POS))
    {
     if(OrderSymbol()==Symbol())
     {
      if(OrderMagicNumber()==Magic)
      {
       Ticket=OrderTicket();
       AnzahlOrderOnSymbol++;
       if(OrderSelect(Ticket,SELECT_BY_TICKET)==True) { close(); }
      }
     }
    }
   }

   if(AnzahlOrderOnSymbol<MaxOrders)  { open(); }
  }

//+------------------------------------------------------------------+
  int open()
  { 
   string Kommentar="";
   int ticket=0;
   bool askKursIstGroesser=False;
   bool bidkKursIstKleiner=False;
   

 
// SELL 
if(BuySellBeides == 2 || BuySellBeides == 3) 
{

 for(int s=0; s<=anzahlKurse-1; s++) 
   {
   if(debug) Print("bidkurse " + s + " " + bidKurs[s] + " " + bidKurs[s+1] );
      if(bidKurs[s] < bidKurs[s+1])
      {
        if(debug)Print("bidKurs " + s);
        bidkKursIstKleiner=True;
      }
      else
      {
      bidkKursIstKleiner=False;
      break;
      }
   }     


        if(bidkKursIstKleiner==True)
         {
          Kommentar = bidKurs[0] + " " + bidKurs[1] + " " +  bidKurs[2] + " " +  lastTickBid;
          ticket=OrderSend(Symbol(),OP_SELL,Lots,lastTickBid,Slippage,0,0, Kommentar, Magic,0,clrGreen);
          if(ticket<0)
          {
           Print("SELL OrderSend failed with error #",GetLastError());
           Print("Symbol:",Symbol()," OP_SELL"," Lots:",Lots,"Bid:",lastTickBid," Slippage:",Slippage," StopLoss:",StopLoss);
         }
         else
           Print("SELL OrderSend placed successfully");
       }
   }

// BUY 
if(BuySellBeides == 1 || BuySellBeides == 3) 
{
   for( s=0; s<=anzahlKurse-1; s++) 
   { 
         if(debug) Print(askKurs[s] + " " + askKurs[s+1] );
      if(askKurs[s] > askKurs[s+1]) 
      {
          if(debug)Print("askKursIstGroesser " + s);
        askKursIstGroesser=True;
      }
      else
      {
      askKursIstGroesser=False;
      break;
      }
   }
   Print(askKursIstGroesser);
 

        if(askKursIstGroesser==True)
        {
         Kommentar = askKurs[0] + " " + askKurs[1] + " " +  askKurs[2] + " " +  lastTickBid ;
         ticket=OrderSend(Symbol(),OP_BUY,Lots,Ask,Slippage,0,0, Kommentar, Magic,0,clrGreen);
         Kaufkurs= lastTickAsk;
         Print(Lots,lastTickAsk,Slippage,StopLoss,TakeProfit);
         if(ticket<0)
         {
          Print("BUY OrderSend failed with error #",GetLastError());
          Print("Symbol:",Symbol()," OP_BUY"," Lots:",Lots,"Ask:",lastTickAsk," Slippage:",Slippage," StopLoss:",StopLoss);
        }
        else
          Print("BUY OrderSend placed successfully");
        }
      }
      
}
// ---------------------------------------------------------------------------------


void close()
{
// Close is executed when script find opened order on current symbol
if(True)
{
 if(OrderType()==OP_BUY)
 {
  if(lastTickBid > Kaufkurs)
   OrderClose(OrderTicket(),Lots,lastTickBid,30,Red);
}

if(OrderType()==OP_SELL)
{
  if(lastTickAsk < Kaufkurs)
   OrderClose(OrderTicket(),Lots,lastTickAsk,30,Red);
}
}
}

//---------------- Tools

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isneuerBar()
{
 if(prevtime==Time[0])
 {
  neuerBAR=false;
}
else
{
  prevtime=Time[0];
  neuerBAR=true;
}
//if(debug) Print("Neuer Bar um "+TimeToStr(Time[0],TIME_SECONDS));
return(neuerBAR);
}
//+------------------------------------------------------------------+
void  infoAnzeigen()
{
 Comment("LastTick=",TimeToStr(TimeCurrent(),TIME_SECONDS)," | Bar Opening=",TimeToStr(Time[0],TIME_SECONDS),"\n",
   "bid=",lastTickBid," | ","ask=",lastTickAsk,"\n",
   "bidDIFF=",bidKurs[anzahlKurse-1] - bidKurs[0]," | ","askDIFF=",askKurs[0] - askKurs[anzahlKurse-1] ,"\n",
   "Spread= ",modspread,"\n",
   "Nachkommastellen= ",Nachkommastellen,"\n",
   "Point= ",pp,"\n",
   "SLPips= ",SLPips,"\n",
   "Tickvalue= ",MarketInfo(Symbol(),MODE_TICKVALUE),"\n",
   "Ticksize= ",MarketInfo(Symbol(),MODE_TICKSIZE),"\n",
   "Minlot= ",MarketInfo(Symbol(),MODE_MINLOT),"\n",
   "min.Dist bid/ask SL,TP=",Min_Dist
   );
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
