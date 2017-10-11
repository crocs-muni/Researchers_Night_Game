// $Id: RadioCountToLedsC.nc,v 1.7 2010-06-29 22:07:17 scipio Exp $

/*									tab:4
 * Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the University of California nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OlUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Copyright (c) 2002-2003 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */
 
#include "Timer.h"
#include "BlinkMorse.h"
#include "printf.h"
 
/**
 * Implementation of the RadioCountToLeds application. RadioCountToLeds 
 * maintains a 4Hz counter, broadcasting its value in an AM packet 
 * every time it gets updated. A RadioCountToLeds node that hears a counter 
 * displays the bottom three bits on its LEDs. This application is a useful 
 * test to show that basic AM communication and timers work.
 *
 * @author Philip Levis
 * @date   June 6 2005
 */

module BlinkMorseC {
  uses {
    interface Leds;
    interface Boot;
    interface Receive;
    interface AMSend;
    interface Timer<TMilli> as SenderTimer;
    interface Timer<TMilli> as Led0Timer;
    interface Timer<TMilli> as Led2Timer;
    interface SplitControl as AMControl;
    interface Packet;
    interface CC2420Packet;
  }
}
implementation {

  void blinkMorseMessage(uint8_t id);
  message_t packet;
  bool locked;
  uint8_t blinkID;
  uint16_t curPos = 0;
  bool led2On = FALSE;
  bool iAmBlinking = FALSE;
  
  char buff[5];

  event void Boot.booted() {
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
  	
    if (err == SUCCESS) {
      if (TOS_NODE_ID > 0)
        call SenderTimer.startPeriodic(500);
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
    // do nothing
  }
  
  event void SenderTimer.fired() {
  	
	printf("Timer fired!\n");
	printfflush();
	call Leds.led1Toggle();

    if (locked) {
      return;
    }
    else {
      blink_morse_msg_t* bmm = (blink_morse_msg_t*)call Packet.getPayload(&packet, sizeof(blink_morse_msg_t));
      if (bmm == NULL) {
        return;
      }

      bmm->id = TOS_NODE_ID;
      
      // Here we can specify the transmission power
      call CC2420Packet.setPower(&packet, 3);
      
      if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(blink_morse_msg_t)) == SUCCESS) {
        locked = TRUE;
      }
    }
  }

  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, uint8_t len) {
    
    uint16_t rssi;
    
    if (iAmBlinking == TRUE) {
//    	printf("Packet dropped -> I am blinkinkg.\n");
//    	printfflush();
    	return bufPtr;
    }
    
    rssi = call CC2420Packet.getRssi(bufPtr) - 45;
   
    if (len != sizeof(blink_morse_msg_t)) {return bufPtr;}
    else {
      blink_morse_msg_t* bmm = (blink_morse_msg_t*)payload;
      // Here is the threshold when we consider packets as received
      if ( (TOS_NODE_ID == 0) && (rssi > -75) ) {
      	printf("Received RSSI: %d\n", rssi);
      	printfflush();
      	// Here we have to start blinking morse code
      	curPos = 0;
      	switch (bmm->id) {
          case 1:
      	    memcpy(buff, "-xxxx", 5);            
            break;
          case 2:
            memcpy(buff, ".-xxx", 5);
            break;
          case 3:
            memcpy(buff, ".---x", 5);
            break;
          case 4:
            memcpy(buff, "-.xxx", 5);
            break;
          case 5:
            memcpy(buff, ".xxxx", 5);
            break;
          default:
            memcpy(buff, "xxxxx", 5);
            break;
        }
      	blinkMorseMessage(bmm->id);
      }
      return bufPtr;
    }
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    if (&packet == bufPtr) {
      locked = FALSE;
    }
  }
  
  event void Led0Timer.fired() {
  	call Leds.led0Toggle();
  	blinkID--;
  	if(blinkID > 0)
  	  call Led0Timer.startOneShot(500);
  	else
  	  call Led2Timer.startOneShot(1000);
  }
  
  event void Led2Timer.fired() {
  	if (buff[curPos] == '.') {
  		if (led2On == FALSE) {
  		  printf("Morse: .\n");
  		  printfflush();
  		  led2On = TRUE;
  		  call Leds.led2On();
  		  call Led2Timer.startOneShot(500);
  		} else {
  		  led2On = FALSE;
  		  call Leds.led2Off();
  		  call Led2Timer.startOneShot(500);
  		}
  	}
   	if (buff[curPos] == '-') {
  		if (led2On == FALSE) {
  		  printf("Morse: -\n");
  		  printfflush();
  		  led2On = TRUE;
  		  call Leds.led2On();
  		  call Led2Timer.startOneShot(1000);
  		} else {
  		  led2On = FALSE;
  		  call Leds.led2Off();
  		  call Led2Timer.startOneShot(500);
  		}
  	}
  	if (buff[curPos] == 'x') {
  		printf("Morse: x\n");
  		printfflush();
  		iAmBlinking = FALSE;
  		call Led2Timer.stop();
  	}
  	// Move the cursor if the led is off again.
  	if (led2On == FALSE) {
  		curPos++;
  	}
  	
  }
  
  void blinkMorseMessage(uint8_t id) {
  	
  	printf("ID of the sender is: %d\n", id);
  	printfflush();
  	
  	iAmBlinking = TRUE;
  	
  	blinkID = id * 2;
  	
  	call Led0Timer.startOneShot(0);
  }

}