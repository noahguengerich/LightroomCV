"""
Captioning service for LightroomCV. 

Monitors the localhost socket for imcoming jpeg data, generates a 
caption, then transmits that caption to the send socket.

"""

import sys
import os
import socket
import cv2
import logging
import argparse
from tkinter import messagebox as mb
import numpy as np
import time
from datetime import datetime
import torch
from caption import caption_image

dir_path = os.path.dirname(os.path.realpath(__file__))
logging.basicConfig(filename= dir_path + '//pythonLog.log', level=logging.DEBUG, format='%(asctime)s %(message)s')

HEADER_SIZE = 10

"""Connects to a sending socket"""
def socket_client_receive() -> socket.socket:
    # Create a socket object 
    s = socket.socket()         
  
    # Define the port on which you want to connect 
    host = '127.0.0.1'
    port = 55623

    try:
        # connect to the server on local computer 
        logging.debug("starting to connect...")
        s.connect((host, port))
        logging.debug("connected...")

    except:
        logging.debug("Unexpected error")
        raise

    else:
        logging.debug("Else clause")
        return s


"""Receives a picture from a sending socket"""
def receive_message(s: socket.socket) -> str:
    try:
        message_size_string = s.recv(HEADER_SIZE)
        if len(message_size_string) == 0:
            logging.debug("message_size_string == 0")
            return 'False'

    except:
        logging.debug("Unexpected error")
        return 'False'

    else:
        buffer_size = 4096
        logging.debug("size of jpeg: " + message_size_string.decode())
        message_size = int(message_size_string.decode())
        total_data = bytearray()
        timer = 0
        message_size_counter = message_size
        logging.debug("Message size: " + str(message_size_counter))
        while True:
            timer = timer + 1
            if buffer_size > message_size_counter:
                data = s.recv(message_size_counter)
                total_data.extend(data)
                break                
            else:
                data = s.recv(buffer_size)
                message_size_counter = message_size_counter - buffer_size
                logging.debug("Message size counter: " + str(message_size_counter))
            total_data.extend(data)
            logging.debug(len(total_data))
            
            if timer == 1000:
                print("Receive Timer expired")
                break
            
        logging.debug("Exited while loop")
        caption = process_jpeg(total_data)
        return caption


"""
Sends image for captioning.
"""
def process_jpeg(jpeg) -> str:
    global cv_start
    
    nparr = np.frombuffer(bytes(jpeg), np.uint8)
    img_np = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    caption = caption_image(img_np, captioner_path, cv_start, beam_size=5)
    
    cv_start = False
    logging.debug(caption)
    return caption


# Message must be terminated with a newline character '\n'
def socket_client_send() -> socket.socket:
    """Connects to a receiving socket."""
    try:
        # Create a socket object 
        s = socket.socket()         
    
        # Define the port on which you want to connect 
        port = 55624
        host = '127.0.0.1'
        # connect to the server on local computer 
        s.connect((host, port))
        
    except:
        logging.debug("Unexpected error")
        raise

    else:
        logging.debug("Else clause")
        return s

"""
Sends a message from a sending socket. 
Message must be terminated with a newline character '\n'.
String message must be encoded to bytes
"""
def send_socket_message(s: socket.socket, message: str):
    # send a message to the client.
    message_encoded = message.encode()
    s.sendall(message_encoded)
    s.sendall(b'\n')



def main(path):
    print('Captioner service started.')
    print('path: ' + path)
    
    # Start the socket connections
    send_socket = socket_client_send()
    receive_socket = socket_client_receive()
    
    # Update path
    global captioner_path
    captioner_path = path
    
    global cv_start
    cv_start = True

    # To ensure while-loop isn't infinite
    timer = 0

    # Send 'ready' message to begin receiving jpegs
    send_socket_message(send_socket, 'ready')

    while True:
        timer = timer + 1
        caption = receive_message(receive_socket)
        if caption == 'False':
            print("Caption returned false")
            break
        else:
            send_socket_message(send_socket, caption)
        if timer == 1000:
            print("Main timer expired")
            break

    send_socket.close()
    receive_socket.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("path")
    args = parser.parse_args()
    main(args.path)
