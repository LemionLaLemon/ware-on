# Ware-on
## Warehouse management suite for ComputerCraft

Demo (Setup & Usage):

https://github.com/user-attachments/assets/bf5862a1-4937-4805-8cbd-4061022f96b9

Ware-on allows you to 
- Near instantly move items from a "Dropoff Station" to storage without using any hoppers like conventional storage systems
- Completely automate the sorting and transfer of items from storage to an "Access Station"
- Script your own "Access Station" client by sending requests to rednet

Basically: Ware-on is a completely automatic storage system

Now, there is one downside to using ware-on, items are stored randomly in storage, and there is currently no plans to add any sorting.
You will not be able to search for any of your items by hand without looking in each container one by one, and you are locked into using the access station.

# Screenshots
Access Station software

<img width="622" height="350" alt="image" src="https://github.com/user-attachments/assets/35eae7da-9c7b-4a4a-8b27-2cec382e53f0" />

Server

<img width="622" height="353" alt="image" src="https://github.com/user-attachments/assets/e3d9ca73-8258-4e77-b84f-d9fbed1f0735" />

Server Setup

<img width="619" height="324" alt="image" src="https://github.com/user-attachments/assets/64a57498-898a-469b-b682-fc3a1c8fc271" />

The dreaded Warehouse Layout Editor

<img width="616" height="344" alt="image" src="https://github.com/user-attachments/assets/4fac16d3-7ad5-45e5-adae-823c4294c257" />


# Setup
Before setting up any of the software, you will need to have:
- 1 or more computers with a container nearby, this is your "Access Station" where you will request and recieve items
- 1 Advanced Computer, this is your warehouse server
- 1 or more containers dedicated for storge, these will be your "Storage"
- 1 or more container for item input, this will be your "Dropoff Station"

All of the above peripherals need to be connected with a **wired modem**

Here is an example of what it should look like. As long as all of the peripherals are connected by a wired modem, it can be placed anywhere.
<img width="1920" height="1200" alt="image" src="https://github.com/user-attachments/assets/8c0cd2c1-0271-4583-a270-a0f48a051c74" />




# Generating a warehouse.ware file
For advanced users: it's a GUI editor, you can basically skip over this section except step 1 if you dont want to know about what does what. Just run the command from step 1 to get the editor.

The `warehouse.ware` file is used by the server to assign a type to each container.
Each container can be 1 of 3 types: "Access Point", "Storage", or "Dropoff Station"
Access Points need to be paired with a computer, and are used to request and recieve items.
Storage can be any type of container, and is used to store all your items.
Dropoff Stations are where items enter to be shoved in storage by the server.

## 1. Run this download the Warehouse Layout Editor

```
wget https://raw.githubusercontent.com/LemionLaLemon/ware-on/refs/heads/main/WarehouseLayoutEditor.lua
```

It is recommended to install the Layout Editor to the server with a disk drive attached. The rest of this guide will assume you did so. However, installation without a floppy disk is possible.

## 2. Insert a floppy disk into the computer's disk drive
The floppy disk is where the warehouse.ware file will be saved to.

## 3. Launch the editor

```
WarehouseLayoutEditor
```

WarehouseLayoutEditor requires Basalt, a UI library. If it is not found, it will be automatically installed.

## 4. Create a new warehouse
You will be prompted for a place to save your warehouse.ware to. If you have a floppy disk, save it to `/disk/warehouse.ware`. If you do not have a floppy disk, just type in a filename like `warehouse.ware`, and it will be saved to `/warehouse.ware`.
Any name can be used for this file as long as it ends in .ware and the path is valid.

## 5. Select inventory peripherals to be used 
You will be brought to a giant list of all container type peripherals to choose from. Basically just click "Select All" and scroll down to check if there are any peripherals named "top", "bottom", "left", "front", "right", or "back". Peripherals with those names will likely not work, with the server.

## 6. Assign a type to the containers
By default, "Storage" will be set for all containers. You just have to search for your "Dropoff Station" or "Access Point" assigned containers, and assign it to such.
After you're finished, scroll back to the top and click "Save Inventory Assignment".
If nothing happens, wait 5 seconds before continuing (the file is probably saving and the UI wont update)

> [!NOTE]
> If you have many containers and don't feel like using the UI to edit, just click "Save Inventory Assignment", open the saved warehouse.ware file in a text editor with search, and manually assign the container there instead.
> The container types are "Access Station", "Storage", and "Dropoff Station"
> After you are finished assigning the inventory types, return to the Warehouse Layout Editor and load the warehouse.ware file, and continue to Access Station Assignment

## 7. Assign each "Access Station" container a computer
Switch to the "Access Station Assignment" tab and click "Refresh Inventories".
You can now assign a computer's ID to a container.

> [!IMPORTANT]
> This uses the computer's ID from os.getComputerID() and NOT the peripheral id (the "Peripheral "Computer_X" connected to network" message in the chat)

After you're done, click "Save Access Stations", and you can exit the editor.
As per usual, if nothing happens, wait 5 seconds before exiting after saving.

# Installing the Server software
## 1. Download the server setup

```
wget https://raw.githubusercontent.com/LemionLaLemon/ware-on/refs/heads/main/Server/setup.lua
```

## 2. Run the setup

```
setup
```

And then you can just follow the setup, it isnt much.

The Primary Storage path is where `server.lua` and `config.json` will be written to.

## 3. Run the server
You will be given instructions on how to run the server, but if by some miracle you didn't get it

1. Navigate to your primary storage directory (the default is the same folder you're currently in)
2. run `server`

To run the server when the computer starts (I recommend you to set this up btw) add 
`shell.run("/server.lua")` to `/startup` (or whereever server.lua is)

By this point, your Dropoff Stations should start working now. Try just shoving an item to any Dropoff Station type container and the server should pull it to a storage container
If you have enabled non-error logs, you will see
```
MOVE [minecraft:chest_X TO minecraft:chest_X]
```

# Installing the Access Station software
## 1. Download the Access Station software
```
wget https://raw.githubusercontent.com/LemionLaLemon/ware-on/refs/heads/main/AccessStation/AccessStation.lua
```

## 2. Run the Access Station
```
AccessStation
```

## 3. Enter in your server's Host ID
Your server will log its Host ID on startup, just shove that number into the New Configuration Wizard.
If you were brought to the main app instead of a New Configuration Wizard, terminate the app and check for any `config.json` file in the same directory as `AccessStation.lua`. If one exists, delete it with
```
rm config.json
```
Then, rerun `AccessStatio`

And congratulations, you've just set up a warehouse.

# Access Station Usage
The "Re-Render" button will fetch an index of all items from the server. This should be ran before you start adding items to your checkout every time.

## Requesting an item from storage
This can be done in 4 easy steps

1. Find the item you want from storage in the left window
2. Enter how many of that item you want from storage (it is defaulted to either 1 stack of that item or the total amount of the item, if it doesn't add up to one stack)
3. Click `+`
4. Click `Request`

It might take a bit for items to be fetched from storage depending on how large your storage system is.
When all items are fetched (or failed to be fetched) from storage, the "Request Result" screen will show up telling you if any items are missing or any items failed to be fetched.

## Filtering
In this build, you can only filter for items by their name, and it does not support regex. 
If you type `stone` into the Filter For bar and hit enter, all results containing "stone" will show up.

## Exiting
There is no in-built method for closing the Access Station (since you'll likely leave it on forever anyways) so just hold `Ctrl + T` to terminate the program.

## Launching on startup
Similar to the server, add `shell.run("/AccessStation.lua")` to `/startup` (or whereever AccessStation.lua is)
