import 'dart:async';
import 'dart:convert';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:animated_emoji/emoji.dart';
import 'package:animated_emoji/emojis.g.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'dart:typed_data';

// import 'models/issueDetailsModel.dart';
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int? guestMoodSelected;
  int? selectedValue = 1;
  final record = AudioRecorder();
  StreamSubscription<Uint8List>? audioSubscription;
  WebSocketChannel? channel;
  bool isRecording = false;
  bool isCompensationOffered = false;
  Timer? sendTimer;
  issueDetailsModel model = issueDetailsModel();
  TextEditingController cabinTextEditController =TextEditingController();
  TextEditingController nameTextEditController =TextEditingController();
  TextEditingController issueTypeTextEditController =TextEditingController();
  TextEditingController priorityTextEditController =TextEditingController();
  TextEditingController departmentTextEditController =TextEditingController();
  TextEditingController locationTextEditController =TextEditingController();
  TextEditingController compensationTextEditController =TextEditingController();
  TextEditingController conversationSummaryTextEditController =TextEditingController();

  @override
  void dispose() {
    audioSubscription?.cancel();
    channel?.sink.close();
    record.dispose();
    super.dispose();
  }

  Future<void> startRecording() async {
    // audioData.clear();

    if (await record.hasPermission()) {
      final stream = await record.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000, // Adjust if needed
          numChannels: 1,
        ),
      );

      audioSubscription = stream.listen((Uint8List dataChunk) {
        setState(() {
          // audioData.addAll(dataChunk);
        });
      });
    } else {
      print('Permission denied.');
    }
  }

  Future<void> stopRecording() async {
    await record.stop();
    await audioSubscription?.cancel();
    sendTimer?.cancel();
    audioSubscription = null;

    // print('Recording stopped. Data length: ${audioData.length} bytes');

    // Process audioData as needed here
  }
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

  }

  Future<void> initializeRecorder() async {
    if (await record.hasPermission()) {
      channel = WebSocketChannel.connect(
        // Uri.parse('ws://localhost:8000/ws/audio'),
        Uri.parse('wss://on-board-demo.azurewebsites.net/ws/audio'),
      );

      // Listen to recording state changes
      record.onStateChanged().listen((state) {
        print("Recording state: $state");
        setState(() {
          isRecording = state == RecordState.record;
        });
      });

      // Start audio stream
      final stream = await record.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      // Buffer to collect audio data before sending
      final buffer = BytesBuilder();

      // Timer to send buffered audio every 100ms

      sendTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (buffer.isNotEmpty && channel?.sink != null) {
          try {
            channel!.sink.add(buffer.toBytes());
          } catch (e) {
            print("WebSocket send error: $e");
          }
          buffer.clear();
        }
      });

      // Listen to audio stream
      audioSubscription = stream.listen(
            (Uint8List dataChunk) {
          buffer.add(dataChunk); // Collect audio into buffer
        },
        onError: (error) {
          print("Audio Stream Error: $error");
          stopRecording();
        },
        onDone: () {
          print("Audio stream completed.");
          stopRecording();
        },
        cancelOnError: true,
      );

      // Listen to WebSocket messages
      channel?.stream.listen(
            (message) {
          print("Message from WebSocket: $message");
          try {
            Map<String, dynamic> valueMap = json.decode(message);
            model = issueDetailsModel.fromJson(valueMap);
            onDataReceived();
          } catch (e) {
            print("JSON Parsing Error: $e");
          }
        },
        onError: (error) {
          print("WebSocket Error: $error");
          stopRecording();
          // Optionally: reconnectWebSocket();
        },
        onDone: () {
          print("WebSocket Disconnected. Reconnecting...");
          stopRecording();
          // Optionally: reconnectWebSocket();
        },
        cancelOnError: true,
      );
    } else {
      print('Permission denied.');
    }
  }

  onDataReceived(){
    if(model.cabin!=null){
      cabinTextEditController.clear();
      setState(() {
        cabinTextEditController.text  = model.cabin??"";
      });
      // viewModel.cabin = model.cabin??"";
    }
    if(model.guestDetails?.firstName!=null){
      setState(() {
        nameTextEditController.clear();
        nameTextEditController.text = model.guestDetails?.firstName??"";
      });
    }
    if(model.guestDetails?.lastName!=null){
      setState(() {
        nameTextEditController.text = "${nameTextEditController.text} ${model.guestDetails?.lastName??""}";
      });
    }
    if(model.guestEmotion!=null){
      setState(() {
        guestMoodSelected = (model.guestEmotion=="angry")?0:
        (model.guestEmotion=="sad")?1:
        (model.guestEmotion=="neutral")?2:
        (model.guestEmotion=="satisfied")?3:
        (model.guestEmotion=="very-happy")?4:null;
      });
    }
    if(model.issueTypeDesc!=null){
      setState(() {
        issueTypeTextEditController.clear();
        issueTypeTextEditController.text = model.issueTypeDesc??"";
      });
    }
    if(model.priorityDesc!=null){
      setState(() {
        priorityTextEditController.clear();
        priorityTextEditController.text = model.priorityDesc??"";
      });
    }
    if(model.level1DepartmentDesc!=null){
      setState(() {
        departmentTextEditController.text = model.level1DepartmentDesc??"";
      });
    }

    if(model.locationId!=null){
      setState(() {
        locationTextEditController.clear();
        locationTextEditController.text = model.locationId.toString()??"";
      });
    }
    if(model.compensation!=null){
      setState(() {
        compensationTextEditController.clear();
        compensationTextEditController.text = model.compensation??"";
      });
    }
    if(model.summary!=null){
      setState(() {
        conversationSummaryTextEditController.clear();
        conversationSummaryTextEditController.text = model.summary??"";
      });
    }

  }

  cancelIssue(){
    setState(() {
     model = issueDetailsModel();
     cabinTextEditController.clear();
    nameTextEditController.clear();
    issueTypeTextEditController.clear();
    priorityTextEditController.clear();
    departmentTextEditController.clear();
    locationTextEditController.clear();
   compensationTextEditController.clear();
    conversationSummaryTextEditController.clear();
     selectedValue = 1;
     guestMoodSelected= null;
    });
    channel?.sink.close();
    record.stop();
    initializeRecorder();
  }

  createIssue(){
    record.stop();
    audioSubscription?.cancel();
    channel?.sink.close();
    // record.dispose();
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents dismissing by tapping outside
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            title: Text(
              "Issue Created",
              style: GoogleFonts.kanit(fontSize: 25, color: Colors.black),
            ),
            content: Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                height: 300,
                width: 300,
                child: Lottie.network(
                  "https://lottie.host/fbc0f00c-6899-48a4-9382-e25be33ab2cd/hMEqUTzCoI.json",
                  repeat: true,
                  reverse: false,
                  animate: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.white,
      body:Container(
        padding: EdgeInsets.all(10),
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          // physics: NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0,right: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Create New Issue",
                      style: GoogleFonts.kanit(fontWeight: FontWeight.bold,fontSize: 35 ,color: Colors.black
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if(!isRecording) {
                          initializeRecorder();
                        }
                        // Add your onPressed functionality here
                      },
                      style: !isRecording? ElevatedButton.styleFrom(
                        backgroundColor: Color(0XFFDE0A26), // Button color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11), // Border radius
                        ),
                        minimumSize: Size(160, 50), // Minimum size of the button
                        elevation:isRecording ? 0 : 5, // Default elevation
                      ).copyWith(
                        elevation: WidgetStateProperty.resolveWith<double>((states) {
                          if (states.contains(WidgetState.pressed)) {
                            return 1; // Reduced elevation when button is pressed
                          }
                          return 5; // Default elevation
                        }),
                      ) :
                      ElevatedButton.styleFrom(
                        backgroundColor: Color(0XFFDE0A26).withOpacity(0.3), // Button color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11), // Border radius
                        ),
                        minimumSize: Size(160, 50), // Minimum size of the button
                        elevation: 5, // Default elevation
                      )
                      ,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/mic.svg',
                            height: 18,
                            width: 15,
                            color: isRecording ? Colors.white.withOpacity(0.5):Colors.white,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Start conversation",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isRecording ? Colors.white.withOpacity(0.5):Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text("AI-assisted issue creation based on guest conversation",
                  style: GoogleFonts.archivoNarrow(fontSize: 14 ,color: Colors.grey
                  ),
                ),
              ),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // Rounded corners
                ),
                color: Colors.blue.shade50, // Light blue background
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue), // Info icon
                      SizedBox(width: 8), // Spacing
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "AI Assistance Active",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue, // Blue text color
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "The AI has analyzed the conversation and pre-filled the form fields. Review and edit as needed before submitting.",
                              style: TextStyle(fontSize: 14, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: cardView(context),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget cardView(BuildContext context){
    return  SizedBox(
      width: MediaQuery.of(context).size.width,
      // height: MediaQuery.of(context).size.width,
      child: Card(
        color: Colors.white,
        elevation: 5,
        child: SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10,),
                        child: guestDetails(context),
                      ) ,
                      // Padding(
                      //   padding: const EdgeInsets.all(15),
                      //   child: issueDetails(context),
                      // ) ,
                      Padding(
                        padding: const EdgeInsets.only(top: 10,),
                        child: locationCard(context),
                      ),
                      // Padding(
                      //   padding: const EdgeInsets.all(15),
                      //   child: compensationDetails(context),
                      // ),
                      // Padding(
                      //   padding: const EdgeInsets.all(15),
                      //   child: conversationSummary(context),
                      // ),
                      // Padding(
                      //     padding: const EdgeInsets.only(right: 20,bottom: 20),
                      //     child: Row(
                      //       mainAxisAlignment: MainAxisAlignment.end,
                      //       children: [
                      //         OutlinedButton(
                      //           onPressed: () {
                      //             // Cancel action
                      //             cancelIssue();
                      //           },
                      //           style: OutlinedButton.styleFrom(
                      //             padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      //             side: BorderSide(color: Colors.grey.shade400), // Light grey border
                      //             shape: RoundedRectangleBorder(
                      //               borderRadius: BorderRadius.circular(6), // Adjusted for less curvature
                      //             ),
                      //           ),
                      //           child: Text(
                      //             "Cancel",
                      //             style: TextStyle(color: Colors.black, fontSize: 16),
                      //           ),
                      //         ),
                      //         SizedBox(width: 12), // Space between buttons
                      //         ElevatedButton(
                      //           onPressed: () {
                      //             // Create Issue action
                      //             createIssue();
                      //           },
                      //           style: ElevatedButton.styleFrom(
                      //             backgroundColor: Colors.blue, // Blue background
                      //             padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      //             shape: RoundedRectangleBorder(
                      //               borderRadius: BorderRadius.circular(6), // Matching the curvature
                      //             ),
                      //           ),
                      //           child: Text(
                      //             "Create Issue",
                      //             style: TextStyle(color: Colors.white, fontSize: 16),
                      //           ),
                      //         ),
                      //       ],
                      //     )
                      // )
                    ],
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10,),
                        child: issueDetails(context),
                      ) ,
                      Padding(
                        padding: const EdgeInsets.all(15),
                        child: compensationDetails(context),
                      ),
                    ],
                  )
                ],
              ),
              conversationSummary(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget guestDetails(BuildContext context){
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left:20,top: 20),
              child: Text("Guest Details",
                style: GoogleFonts.kanit(fontSize: 25 ,color: Colors.black
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:20,top: 20),
              child: Text("Starteroom/Cabin/Residence/Suite",
                style: GoogleFonts.kanit(fontSize: 14 ,color: Colors.black
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:20,top: 5,right: 20),
              child: TextFormField(
                controller: cabinTextEditController,
                cursorColor: Colors.grey,
                onChanged: (value) {
                },
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Light grey outline
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade500), // Slightly darker grey when focused
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Default border color
                  ),
                  hoverColor: Colors.grey,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:20,top: 20),
              child: Text("Guest name (First & Last)",
                style: GoogleFonts.kanit(fontSize: 14 ,color: Colors.black
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:20,top: 5,right: 20),
              child: TextFormField(
                controller: nameTextEditController,
                onChanged: (value) {
                },
                cursorColor: Colors.grey,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Light grey outline
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade500), // Slightly darker grey when focused
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Default border color
                  ),
                  hoverColor: Colors.grey,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:20,top: 20),
              child: Text("Guest mood",
                style: GoogleFonts.kanit(fontSize: 14 ,color: Colors.black
                ),
              ),
            ),
            Container(
              margin:  const EdgeInsets.only(left:20,top: 5,right: 20),
              width: MediaQuery.of(context).size.width * 0.5,
              height: 50,
              // color: Colors.red,
              child: Row(
                // scrollDirection: Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        guestMoodSelected= 0;
                      });
                    },
                    child: Container(
                      decoration: guestMoodSelected==0? BoxDecoration(
                        color: Colors.blue.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 2), // Outline
                      ) : null,
                      padding: EdgeInsets.all(8),
                      child: const AnimatedEmoji(
                        AnimatedEmojis.rage,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        guestMoodSelected= 1;
                      });
                    },
                    child: Container(
                      decoration: guestMoodSelected==1? BoxDecoration(
                        color: Colors.blue.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 2), // Outline
                      ) : null,
                      padding: EdgeInsets.all(8),
                      child: const AnimatedEmoji(
                        AnimatedEmojis.sad,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        guestMoodSelected= 2;
                      });
                    },
                    child: Container(
                      decoration: guestMoodSelected==2? BoxDecoration(
                        color: Colors.blue.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 2), // Outline
                      ) : null,
                      padding: EdgeInsets.all(8),
                      child: const AnimatedEmoji(
                        AnimatedEmojis.neutralFace,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        guestMoodSelected= 3;
                      });
                    },
                    child: Container(
                      decoration: guestMoodSelected==3? BoxDecoration(
                        color: Colors.blue.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 2), // Outline
                      ) : null,
                      padding: EdgeInsets.all(8),
                      child: const AnimatedEmoji(
                        AnimatedEmojis.warmSmile,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        guestMoodSelected= 4;
                      });
                    },
                    child: Container(
                      decoration: guestMoodSelected==4? BoxDecoration(
                        color: Colors.blue.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 2), // Outline
                      ) : null,
                      padding: EdgeInsets.all(8),
                      child: const AnimatedEmoji(
                        AnimatedEmojis.smile,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget issueDetails(BuildContext context){
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left:20,top: 20),
              child: Text("Issue Details",
                style: GoogleFonts.kanit(fontSize: 25 ,color: Colors.black
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:20,top: 20),
              child: Text("Issue Type",
                style: GoogleFonts.kanit(fontSize: 14 ,color: Colors.black
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:20,top: 5,right: 20),
              child:TextFormField(
                controller: issueTypeTextEditController,
                onChanged: (value) {
                },
                cursorColor: Colors.grey,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Light grey outline
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade500), // Slightly darker grey when focused
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Default border color
                  ),
                  hoverColor: Colors.grey,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:20,top: 20),
              child: Text("Priority",
                style: GoogleFonts.kanit(fontSize: 14 ,color: Colors.black
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:20,top: 5,right: 20),
              child: TextFormField(
                controller: priorityTextEditController,
                onChanged: (value) {
                },
                cursorColor: Colors.grey,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Light grey outline
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade500), // Slightly darker grey when focused
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Default border color
                  ),
                  hoverColor: Colors.grey,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:20,top: 20),
              child: Text("Department",
                style: GoogleFonts.kanit(fontSize: 14 ,color: Colors.black
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:20,top: 5,right: 20),
              child: TextFormField(
                controller: departmentTextEditController,
                onChanged: (value) {
                },
                cursorColor: Colors.grey,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Light grey outline
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade500), // Slightly darker grey when focused
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Default border color
                  ),
                  hoverColor: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget locationCard(BuildContext context){
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left:20),
            child: Text("Location",
              style: GoogleFonts.kanit(fontSize: 25 ,color: Colors.black
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left:20,),
            child: Text("Location of issue",
              style: GoogleFonts.kanit(fontSize: 14 ,color: Colors.black
              ),
            ),
          ),
          Padding(
              padding: const EdgeInsets.only(left:20,top: 5,right: 20),
              child: TextFormField(
                controller: locationTextEditController,
                onChanged: (value) {
                  // viewModel.locationId = value;
                },
                cursorColor: Colors.grey,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Light grey outline
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade500), // Slightly darker grey when focused
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Default border color
                  ),
                  hoverColor: Colors.grey,
                ),
              )
          ),
        ],
      ),
    );
  }

  Widget compensationDetails(BuildContext context){
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.4,
      child:Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compensation',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: isCompensationOffered,
                onChanged: (value) {
                  setState(() {
                    isCompensationOffered = value;
                  });
                },
                activeColor: Colors.blue,
              ),
              SizedBox(width: 8),
              Text('Offer Compensation'),
            ],
          ),
          SizedBox(height: 8),
          Text('Compensation Type'),
          SizedBox(height: 4),
          TextField(
            enabled: isCompensationOffered,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter compensation type',
            ),
          ),
        ],
      ),
    );
  }

  Widget conversationSummary(BuildContext context){
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left:20),
              child: Text("Conversation Summary",
                style: GoogleFonts.kanit(fontSize: 25 ,color: Colors.black
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:20),
              child: Text("Comment",
                style: GoogleFonts.kanit(fontSize: 14 ,color: Colors.black
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left:20,top: 5,right: 20),
              child: TextFormField(
                controller: conversationSummaryTextEditController,
                onChanged: (value) {
                },
                maxLines: 3,
                cursorColor: Colors.grey,
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Light grey outline
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade500), // Slightly darker grey when focused
                  ),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade300), // Default border color
                  ),
                  hoverColor: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class issueDetailsModel {
  int? issueTypeId;
  String? issueTypeDesc;
  String? priorityDesc;
  String? issueGroupDesc;
  String? level1DepartmentDesc;
  String? cabin;
  GuestDetails? guestDetails;
  int? locationId;
  String? guestEmotion;
  String? summary;
  String? compensation;

  issueDetailsModel(
      {this.issueTypeId,
        this.issueTypeDesc,
        this.priorityDesc,
        this.issueGroupDesc,
        this.level1DepartmentDesc,
        this.cabin,
        this.guestDetails,
        this.locationId,
        this.guestEmotion,
        this.summary,
        this.compensation});

  issueDetailsModel.fromJson(Map<String, dynamic> json) {
    issueTypeId = json['issueTypeId'];
    issueTypeDesc = json['issueTypeDesc'];
    priorityDesc = json['priorityDesc'];
    issueGroupDesc = json['IssueGroupDesc'];
    level1DepartmentDesc = json['level1DepartmentDesc'];
    cabin = json['cabin'];
    guestDetails = json['guestDetails'] != null
        ? new GuestDetails.fromJson(json['guestDetails'])
        : null;
    locationId = json['locationId'];
    guestEmotion = json['guestEmotion'];
    summary = json['summary'];
    compensation = json['compensation'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['issueTypeId'] = this.issueTypeId;
    data['issueTypeDesc'] = this.issueTypeDesc;
    data['priorityDesc'] = this.priorityDesc;
    data['IssueGroupDesc'] = this.issueGroupDesc;
    data['level1DepartmentDesc'] = this.level1DepartmentDesc;
    data['cabin'] = this.cabin;
    if (this.guestDetails != null) {
      data['guestDetails'] = this.guestDetails!.toJson();
    }
    data['locationId'] = this.locationId;
    data['guestEmotion'] = this.guestEmotion;
    data['summary'] = this.summary;
    data['compensation'] = this.compensation;
    return data;
  }
}

class GuestDetails {
  String? firstName;
  String? lastName;

  GuestDetails({this.firstName, this.lastName});

  GuestDetails.fromJson(Map<String, dynamic> json) {
    firstName = json['firstName'];
    lastName = json['lastName'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['firstName'] = this.firstName;
    data['lastName'] = this.lastName;
    return data;
  }
}