import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JobsPage extends StatefulWidget {
  @override
  _JobsPageState createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _jobDescriptionController = TextEditingController();
  final TextEditingController _jobLocationController = TextEditingController();
  final TextEditingController _jobSalaryController = TextEditingController();
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  List<Map<String, dynamic>> jobListings = [];

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  Future<void> _fetchJobs() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('jobs').get();
    setState(() {
      jobListings = snapshot.docs.map((doc) {
        Map<String, dynamic> jobData = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
        jobData['hasApplied'] = (jobData['applicants'] ?? []).contains(userId);
        jobData['applicantCount'] = (jobData['applicants'] ?? []).length;
        return jobData;
      }).toList();
    });
  }

  Future<void> _addJob() async {
    if (_jobTitleController.text.isNotEmpty && _jobDescriptionController.text.isNotEmpty) {
      await FirebaseFirestore.instance.collection('jobs').add({
        'title': _jobTitleController.text,
        'description': _jobDescriptionController.text,
        'location': _jobLocationController.text,
        'salary': _jobSalaryController.text,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'applicants': [], // List to hold applicants
      });
      _jobTitleController.clear();
      _jobDescriptionController.clear();
      _jobLocationController.clear();
      _jobSalaryController.clear();
      _fetchJobs(); // Refresh job listings after adding a new job
      Navigator.of(context).pop(); // Close the dialog
    }
  }

  Future<void> _applyForJob(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'applicants': FieldValue.arrayUnion([userId]), // Add the current user to the applicants list
    });
    _fetchJobs(); // Refresh job listings after applying
  }

  void _showAddJobDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Job'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _jobTitleController,
                decoration: InputDecoration(labelText: 'Job Title'),
              ),
              TextField(
                controller: _jobDescriptionController,
                decoration: InputDecoration(labelText: 'Job Description'),
              ),
              TextField(
                controller: _jobLocationController,
                decoration: InputDecoration(labelText: 'Job Location'),
              ),
              TextField(
                controller: _jobSalaryController,
                decoration: InputDecoration(labelText: 'Salary'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: _addJob,
              child: Text('Add Job'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Job Openings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: jobListings.isNotEmpty
          ? ListView.builder(
        itemCount: jobListings.length,
        itemBuilder: (context, index) {
          final job = jobListings[index];
          return _buildJobCard(job);
        },
      )
          : Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddJobDialog,
        child: Icon(Icons.add),
        backgroundColor: Color.fromRGBO(0, 153, 114, 1),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => JobDetailsPage(job: job),
          ),
        );
      },
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.grey[800],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job['title'] ?? 'Title',
                style: TextStyle(color: Colors.white70),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: job['hasApplied'] ? null : () => _applyForJob(job['id']),
                    child: Text(
                      job['hasApplied'] ? 'Applied' : 'Apply',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  Text(
                    '${job['applicantCount']} Applicants',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JobDetailsPage extends StatelessWidget {
  final Map<String, dynamic> job;

  JobDetailsPage({required this.job});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(job['title'] ?? 'Job Details'),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job['title'] ?? 'Job Title',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Description: ${job['description'] ?? 'No Description'}',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            SizedBox(height: 8),
            Text(
              'Location: ${job['location'] ?? 'Unknown Location'}',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            SizedBox(height: 8),
            Text(
              'Salary: ${job['salary'] ?? 'Not specified'}',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            SizedBox(height: 16),
            Text(
              '${job['applicantCount']} Applicants',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
