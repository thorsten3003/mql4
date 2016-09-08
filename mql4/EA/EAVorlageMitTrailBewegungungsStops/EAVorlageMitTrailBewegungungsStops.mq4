//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                    tsEATest1.mq4 |
//|                                                Thorsten Stratmann|
//|                                                                  |
//+------------------------------------------------------------------+

#property copyright "Thorsten Stratmann"
#property link      "thorsten@tstratmann.de"
#property version   "101.101"
//+------------------------------------------------------------------+
//-- Trailstop
extern bool   AllPositions  =False;         // AllPositions - use trailing stop for all opened positions
extern bool   ProfitTrailing=True;          // ProfitTrailing - trailing stop is activated as soon as the trade starts making profits, and used to protect profits. If "false" - trailing stop will be activated as soon as a new position is opened.
extern int    TrailingStop  =15;            // TrailingStop - fixed size of the trailing stop
extern int    TrailingStep  =2;              // TrailingStep - step of the trailing stop
//------------------------------------------------------------------------------- 1 --
//-- Bewegungsstop Markttechnik
bool bar0=true;                        // bei true wird erster SL auf Bar0 gelegt, sonst Bar1
input bool debug=false;
input int barsInnenstaebe=20;               // Anzahl Bars zur Bestimmung ob Innenstaebe vorliegen
input bool InnenstaebeBeruecksichtigen=true; // SOllen die Innenstaebe bei buy/sell  beruecksichtigt werden
datetime prevtime;                           // zur Erkennung ob ein neuer Bars angefangen hat
double HighKurs=0.00;
double LowKurs=0.00;
int schleifenzaehler=0;   
// zur Innenstab berechnung
double einAustiegHochkurs;
double einAustiegTiefkurs;
bool Innenstab=false;
int NrAussenstab=0;
//------------------------------------------------------------------------------- 2--
//-- Allgemeine Einstellungen
input int Magic = 101101; // Magic number
input double MaximumRisk   =0.02;
input double Lot = 0.1;
input bool AutoLots = True; // if its True it will automatically calculate Lot based on Accont Balance. Go down to open() function to see how does it work.
input int TakeProfit = 5000;  // Take profit level, Ask + ( TakeProfit * Point )
input int StopLoss = 5000;     //Stop loss level,    Ask - ( StopLoss * Point ) 
input int Slippage = 3; //Maximum price slippage for buy or sell orders
input int MaxOrders = 1; // How many orders script can open on current symbol
input int Pips = 20; // How far ( in pips ) from actual price sellstop / buystop order will be placed.
input int Mins = 30; // Lifetime of buystop / sellstop order ( in minutes ) after it is deleted if not reached open price. 
input int MaxSpread = 30; // If spread is above 30, orders will not be opened  
int Ticket;
int AllowBuySell = 2; // AllowBuySell = 2 mean script can make sell and buy orders. 0 mean it can only buy. 1 mean it can only sell.
double lows, highs, low, high, range, SL; // To learn how does AllowBuySell works look down in open() script.
// low, high and range are used in Scan Loop which calculate the highest and the lowest Order Price in the past. Range show how many pips are beetwen high and low value
double spread;
double Min_Dist;
bool neuerBAR;
double modspread;
int Nachkommastellen;   
   
void OnTick() { // Executed when there is new tick.

   Nachkommastellen =MarketInfo(Symbol(),MODE_DIGITS);
   spread=MarketInfo(Symbol(),MODE_SPREAD);     // Abstand des Haendler zw. bid und ask
   Min_Dist =MarketInfo(Symbol(),MODE_STOPLEVEL);  //Min. distance zw. bid/ask und SL bzw. TP
   neuerBAR=true;          // nur wenn neuer Bar anfaengt arbeitet der EA
   int AnzahlOrderOnSymbol=0;

  Comment( "LastTick=",TimeToStr(TimeCurrent(),TIME_SECONDS)," | Bar Opening=",TimeToStr(Time[0],TIME_SECONDS),"\n",
           "bid=",Bid, " | ", "ask=",Ask , "\n",
           "Spread= ", spread, "\n",
           "Nachkommastellen= ", Nachkommastellen, "\n",
           "Point= ", MarketInfo(Symbol(),MODE_POINT), "\n",
           "Tickvalue= " , MarketInfo(Symbol(),MODE_TICKVALUE), "\n",
           "Ticksize= ", MarketInfo(Symbol(),MODE_TICKSIZE), "\n", 
           "Minlot= ", MarketInfo(Symbol(),MODE_MINLOT), "\n",
           "min.Dist bid/ask SL,TP=", Min_Dist
           );
                  

   for ( int n = 0; n < OrdersTotal(); n++ ) {  // That loop search if there is opened order on current symbol.
      if ( OrderSelect ( n, SELECT_BY_POS ) ) {  
         if ( OrderSymbol() == Symbol() ) {  
            if ( OrderMagicNumber() == Magic ) {  
               Ticket = OrderTicket();  
               if ( OrderSelect ( Ticket, SELECT_BY_TICKET ) == True ) 
                  { 
                     close(); // If it found opened order, script jump to close() function which close orders and make trailing stops.
                  } 
               AnzahlOrderOnSymbol++;
            }
         }
      }
   }

   if ( AnzahlOrderOnSymbol < MaxOrders ) { open(); } // If MaxOrders are not reached it allow script to open one more order in order() function.
}

//---------------------------------------------------------------------------------
int open() {  
   double Lots;
   
//----------------------MoneyManagement --------------------------------
   if ( AutoLots == False ) 
     { 
       Lots = Lot; 
     }  
   else 
     { 
       Lots = MathRound ( AccountBalance() / 100 ) / 100; 
     } // First 100 say, that every 100$ will will increase lot by 1 point.
       // Second 100 say, that 1 point is equal to 0.01 lot
       // For ex. if you want to play 0.5 Lot with 1000$ account you can write MathRound ( AccountBalance() / 20 ) / 100;
//---------------------------------------------------------------------------------   

// Here you can place indicators and all stuff
// Which will calculate when script should buy or sell.
  
  int handel=0;  // 0 nichts, 1 buy, 2 sell
 
//--- get minimum stop level
   double minstoplevel=MarketInfo(Symbol(),MODE_STOPLEVEL);
   Print("Minimum Stop Level=",minstoplevel," points");
   double price=Ask;
//--- calculated SL and TP prices must be normalized
   double stoploss=NormalizeDouble(Bid-minstoplevel*Point,Digits);
   double takeprofit=NormalizeDouble(Bid+minstoplevel*Point,Digits);
//--- place market order to buy 1 lot
   int ticket=OrderSend(Symbol(),OP_BUY,0.1,price,30,0,0,"My order",Magic,0,clrGreen);
   if(ticket<0)
     {
      Print("OrderSend failed with error #",GetLastError());
     }
   else
      Print("OrderSend placed successfully");
//---


return ( 0 );
}

// ---------------------------------------------------------------------------------

int close() { // Close is executed when script find opened order on current symbol
  trailingstop();
  //  bewegungsstop();
   
   return(0);
}
// ---------------------------------------------------------------------------------

void bewegungsstop() {
   bool Schleife=true;

   
      modspread=NormalizeDouble( (spread*Point),Digits);
      Min_Dist=NormalizeDouble( (Min_Dist*Point),Digits);
   


   if(Bars < barsInnenstaebe)                       // es werden soviele Bars muessen min. im Chart sein um die Innenstaebe zu bestimmen
     {
      Alert("Nicht genug Bars im Fenster.  Mindestens " + barsInnenstaebe + ". EA arbeitet nicht!");                                   // Exit start()
     }

   // bestimmt ob neuer Bar beginnt
   if(prevtime==Time[0])           
     {
        neuerBAR=false;
     }
     else
     {
       prevtime=Time[0];
       neuerBAR=true;
     }         
     if(debug) Print("Neuer Bar um "+ TimeToStr(Time[0],TIME_SECONDS));     
//------------------------------------------------------------------------------- 
    
            int Tip=OrderType();                   // Order type
            if(debug) Print("Verarbeite Order: " + Ticket + " - " +OrderTicket());      
            
            SL    =OrderStopLoss();      // SL of the selected order
            double modifySL =0.00;              // das wird der neue SL
            double TP    =OrderTakeProfit();    // TP of the selected order
            double Price =OrderOpenPrice();     // Price of the selected order
            string Text="";           
            bool Modify=false;                  // Order wird bei true mofifiziert                          
 //---------------------------------------------------------------------- 3 --
                       
            switch(Tip)                         // By order type
              {
               case 0 :                         //  BUY Order
                  if(debug) Print("Case 0: BUY ORDER");
                  if( calcInnenstab() ) 
                  {  if(debug) Print("Innenstab vorhanden");
                     modifySL=NormalizeDouble(Low[NrAussenstab],Digits);     //SL auf Aussenstab (bid) setzen 
                     Text="SL der Buy Order auf Aussenstab Low="+ modifySL;        // Text for Buy 
                     Modify=true;      // To be modified
                  }
                  else if(bar0==true)
                        {  
                           bar0=false;       // ab dem zweiten Durchlauf Bar1 nehmen
                           modifySL=NormalizeDouble(Low[0],Digits);  //SL auf das Low (bid) von Bar0 setzen
                           Text="SL der Buy Order auf: bar0 Low="+ modifySL;        // Text for Buy 
                           Modify=true;      // To be modified
                        }
                        else
                        {
                           modifySL=NormalizeDouble(Low[1],Digits);  //SL auf das Low (bid) von Bar1 setzen
                           Text="SL der Buy Order auf: bar1 Low="+ modifySL;        // Text for Buy 
                           Modify=true;      // To be modified
                        }                      
            
            
               if (Bid - modifySL < Min_Dist)  // If less than allowed
                 { double test = Bid - modifySL;
                   Print("Bid:"+ Bid + "-modifySL:" + modifySL + "=" + test + "<Min_Dist:"+Min_Dist+"  Mindestabstand nicht erreicht. SL kann nicht geändert werden.");
                   Modify=false;
                 }
               
               break;      // Ende case 0: 

               case 1 :                // SELL ORDER
                  if(debug) Print("Case 1: SELL ORDER");
                  if( calcInnenstab() ) 
                  {
                     modifySL=NormalizeDouble( (High[NrAussenstab]+modspread),Digits);     //SL auf Aussenstab setzen (ask)
                     Text="SL der SELL Order anzupassen auf Aussenstab High="+ modifySL;        // Text for Buy 
                     Modify=true;      // To be modified
                  }
                  else if(bar0==true)
                        {
                           bar0=false;       // ab dem zweiten Durchlauf Bar1 nehmen
                           modifySL=NormalizeDouble( (High[0]+modspread),Digits);  //SL auf das High (ask) von Bar0 setzen
                           Text="SL der SELL Order auf: bar0 High="+ modifySL;        // Text for Buy 
                           Modify=true;      // To be modified
                        }
                        else
                        {
                           modifySL=NormalizeDouble( (High[1]+modspread),Digits);  //SL auf das High (ask) von Bar1 setzen
                           Text="SL der SELL Order auf: bar1 High="+ modifySL;        // Text for Buy 
                           Modify=true;      // To be modified
                        }   
                        
                if (modifySL - Ask < Min_Dist)  // If less than allowed
                 {  test = modifySL - Ask;
                   Print("Ask:"+ Ask + "-modifySL:" + modifySL + "=" + test + "<Min_Dist:"+Min_Dist+"  Mindestabstand nicht erreicht. SL kann nicht geändert werden.");
                   Modify=false;
                 }
                 
                                             
               } // End of switch
           
               Print("End Switch- akt.SL:"+SL + " , modifySL:"+modifySL+ " ,modspread:"+modspread );
               Print("Price:"+ Price);   

            //ist der SL gleich dem neuen SL? dann nicht aendern
            if(NormalizeDouble(SL,Digits)==NormalizeDouble(modifySL,Digits)) 
            {
               Modify=false;
            }
 //-------------------------------------------------------------------
            if (Modify==true)                 
               {              // Beginn Order verändern
                  schleifenzaehler=0;
                  while(Schleife==true)                            // Im Fehlerfall kann Order wiederholt werden
                 { 
                  schleifenzaehler++;
                  if(schleifenzaehler>=10) Schleife=false; // max. 10 Versuche

                  if(debug) Print ("Versuche ",Text,Ticket);
                  bool Ans=OrderModify(Ticket,Price,modifySL,TP,0);//Modify it!
   
//------------------------------------------------------------------- 6 --
                  if (Ans==true)                      // Order wurde geaendert
                    {
                     if(debug) Print("Order ",Ticket," wurde erfolgreich geaendert.)");
                     break;                           // while Schleife verlassen
                    }
                  //------------------------------------------------------------------- 7 --
                  int Error=GetLastError();           // Failed :(
                  switch(Error)                       // Overcomable errors
                    {
                     case 130:Print("Falsche Stops");
                        break;                     
                     case 136:Print("No prices. Waiting for a new tick..");
                        while(RefreshRates()==false)  // To the new tick
                           Sleep(1);                  // Cycle delay
                        continue;                     // At the next iteration
                     case 146:Print("Trading subsystem is busy. Retrying ");
                        Sleep(500);                   // Simple solution
                        RefreshRates();               // Update data
                        continue;                     // At the next iteration
                        // Critical errors
                     case 2 : Print("Common error.");
                        break;                        // Exit 'switch'
                     case 5 : Print("Old version of the client terminal.");
                        break;                        // Exit 'switch'
                     case 64: Print("Account is blocked.");
                        break;                        // Exit 'switch'
                     case 133:Print("Trading is prohibited");
                        break;                        // Exit 'switch'
                     default: Print("Occurred error ",Error);//Other errors
                    }
                  break;                              // From modification cycle
                 }                                    // End of modification cycle
            }                                         // Ende if(Modify==true)                                
   }    // Ende start
  



bool calcInnenstab()
{
   for(int i=barsInnenstaebe; i>=2; i--)          
      {
         Innenstab=true;
         NrAussenstab=0;
         int k=i;
      if(debug) Print("forloop- i="+i);
            while(Innenstab==true) 
            {
               k--;
               if(debug) Print("whileloop - k="+k);
               einAustiegKursBerechnen(k);
               
               if( (High[i] >= einAustiegHochkurs) && 
                   (Low[i]  <= einAustiegTiefkurs )  )
               {
                  Innenstab=true;
                  NrAussenstab=i;
                  if(debug) Print("Innenstab=JA");
               }
               else
               {
                  Innenstab=false;
                  NrAussenstab=0;
                  if(debug) Print("Innenstab=NEIN");
               }
            if(k==1) break;      //Wenn Innenstaebe bis zum Ende vorhanden dann while beenden
            }     // end while
      if(k==1) break;            //Wenn Innenstaebe bis zum Ende vorhanden dann auch forloop beenden
      }           // end for
      if(debug) Print("Innenstab="+Innenstab+ " NrAussenstab="+NrAussenstab);
   if( ! InnenstaebeBeruecksichtigen){ Innenstab=false;}
   return(Innenstab);
}

int einAustiegKursBerechnen(int k)
{
   if(Open[k]>=Close[k])
      {
         einAustiegHochkurs = Open[k];
         einAustiegTiefkurs = Close[k];
      }
   else
      {
         einAustiegHochkurs = Close[k];
         einAustiegTiefkurs = Open[k];
      }
if(debug) Print("einAustiegHochkurs="+einAustiegHochkurs+" einAustiegTiefkurs="+einAustiegTiefkurs);
return(0);
}


// ---------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------
void trailingstop()
{
double pBid, pAsk, pp;
//----
   pp=MarketInfo(OrderSymbol(), MODE_POINT);
     if (OrderType()==OP_BUY) 
     {
      pBid=MarketInfo(OrderSymbol(), MODE_BID);
        if (!ProfitTrailing || (pBid-OrderOpenPrice())>TrailingStop*pp) 
        {
           if (OrderStopLoss()<pBid-(TrailingStop+TrailingStep-1)*pp) 
           {
            ModifyStopLoss(pBid-TrailingStop*pp);
            return;
           }
        }
     }
     if (OrderType()==OP_SELL) 
     {
      pAsk=MarketInfo(OrderSymbol(), MODE_ASK);
        if (!ProfitTrailing || OrderOpenPrice()-pAsk>TrailingStop*pp) 
        {
           if (OrderStopLoss()>pAsk+(TrailingStop+TrailingStep-1)*pp || OrderStopLoss()==0) 
           {
            ModifyStopLoss(pAsk+TrailingStop*pp);
            return;
           }
        }
     }
  }

  void ModifyStopLoss(double ldStopLoss) 
  {
   bool fm;
   fm=OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLoss,OrderTakeProfit(),0,CLR_NONE);
  }


       
