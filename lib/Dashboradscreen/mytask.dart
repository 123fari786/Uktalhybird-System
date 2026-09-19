// import 'package:flutter/material.dart';

// class TaskScreen extends StatefulWidget {
//   const TaskScreen({super.key});

//   @override
//   State<TaskScreen> createState() => _TaskScreenState();
// }

// class _TaskScreenState extends State<TaskScreen> {
//   final List<Task> tasks = [
//     Task(
//       title: "Complete Profile",
//       description: "Fill your complete profile information",
//       completed: true,
//       reward: "+50 Points",
//     ),
//     Task(
//       title: "Verify Email",
//       description: "Verify your email address",
//       completed: true,
//       reward: "+20 Points",
//     ),
//     Task(
//       title: "Add Payment Method",
//       description: "Add at least one payment method",
//       completed: false,
//       reward: "+30 Points",
//     ),
//     Task(
//       title: "Invite 5 Friends",
//       description: "Invite 5 friends to join the platform",
//       completed: false,
//       reward: "+100 Points",
//     ),
//     Task(
//       title: "First Deposit",
//       description: "Make your first deposit",
//       completed: false,
//       reward: "+200 Points",
//     ),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: const Text(
//           "My Tasks",
//           style: TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.w600,
//             fontSize: 18,
//           ),
//         ),
//         centerTitle: true,
//         backgroundColor: const Color(0xFF0000FF),
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         shape: const RoundedRectangleBorder(
//           borderRadius: BorderRadius.only(
//             bottomLeft: Radius.circular(25),
//             bottomRight: Radius.circular(25),
//           ),
//         ),
//       ),
//       body: Column(
//         children: [
//           // White content area
//           Expanded(
//             child: Padding(
//               padding: EdgeInsets.all(screenWidth * 0.04),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   SizedBox(height: screenHeight * 0.02),
//                   Text(
//                     "Your Tasks",
//                     style: TextStyle(
//                       fontSize: screenWidth * 0.05,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black87,
//                     ),
//                   ),
//                   SizedBox(height: screenHeight * 0.01),
//                   Text(
//                     "Complete these tasks to unlock rewards",
//                     style: TextStyle(
//                       fontSize: screenWidth * 0.038,
//                       color: Colors.grey[600],
//                     ),
//                   ),
//                   SizedBox(height: screenHeight * 0.03),
//                   Expanded(
//                     child: ListView.builder(
//                       itemCount: tasks.length,
//                       itemBuilder: (context, index) {
//                         final task = tasks[index];
//                         return _buildTaskItem(task, screenWidth, screenHeight);
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTaskItem(Task task, double screenWidth, double screenHeight) {
//     return Container(
//       margin: EdgeInsets.only(bottom: screenHeight * 0.02),
//       padding: EdgeInsets.all(screenWidth * 0.04),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(15),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.1),
//             blurRadius: 10,
//             spreadRadius: 2,
//             offset: const Offset(0, 2),
//           ),
//         ],
//         border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
//       ),
//       child: Row(
//         children: [
//           // Task status icon
//           Container(
//             width: screenWidth * 0.12,
//             height: screenWidth * 0.12,
//             decoration: BoxDecoration(
//               color: task.completed
//                   ? Colors.green.withOpacity(0.1)
//                   : const Color(0xFF0000FF).withOpacity(0.1),
//               shape: BoxShape.circle,
//             ),
//             child: Icon(
//               task.completed
//                   ? Icons.check_circle
//                   : Icons.radio_button_unchecked,
//               color: task.completed ? Colors.green : const Color(0xFF0000FF),
//               size: screenWidth * 0.06,
//             ),
//           ),
//           SizedBox(width: screenWidth * 0.04),
//           // Task details
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Expanded(
//                       // 👈 This prevents overflow
//                       child: Text(
//                         task.title,
//                         style: TextStyle(
//                           fontSize: screenWidth * 0.045,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black87,
//                         ),
//                         overflow:
//                             TextOverflow.ellipsis, // 👈 Adds "..." if too long
//                       ),
//                     ),
//                     SizedBox(width: 8), // 👈 Small gap between title and reward
//                     Text(
//                       task.reward,
//                       style: TextStyle(
//                         fontSize: screenWidth * 0.035,
//                         fontWeight: FontWeight.bold,
//                         color: const Color(0xFF0000FF),
//                       ),
//                     ),
//                   ],
//                 ),

//                 SizedBox(height: screenHeight * 0.005),
//                 Text(
//                   task.description,
//                   style: TextStyle(
//                     fontSize: screenWidth * 0.035,
//                     color: Colors.grey[600],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(width: screenWidth * 0.02),
//           // Complete button or completed status
//           if (task.completed)
//             Container(
//               padding: EdgeInsets.symmetric(
//                 horizontal: screenWidth * 0.03,
//                 vertical: screenHeight * 0.005,
//               ),
//               decoration: BoxDecoration(
//                 color: Colors.green.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 "Completed",
//                 style: TextStyle(
//                   fontSize: screenWidth * 0.03,
//                   color: Colors.green,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             )
//           else
//             InkWell(
//               onTap: () {
//                 setState(() {
//                   task.completed = true;
//                 });
//               },
//               child: Container(
//                 padding: EdgeInsets.symmetric(
//                   horizontal: screenWidth * 0.03,
//                   vertical: screenHeight * 0.01,
//                 ),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF0000FF),
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Text(
//                   "Complete",
//                   style: TextStyle(
//                     fontSize: screenWidth * 0.033,
//                     color: Colors.white,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }

// class Task {s
//   String title;
//   String description;
//   bool completed;
//   String reward;

//   Task({
//     required this.title,
//     required this.description,
//     required this.completed,
//     required this.reward,
//   });
// }
