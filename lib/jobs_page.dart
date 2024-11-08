import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppColors {
  static const primaryGreen = Color(0xFF2E7D32); // Forest Green, primary color
  static const darkBackground = Color(0xFF000000); // Black background
  static const textLight = Color(0xFFFFFFFF); // White text for readability
  static const textDim = Color(0xFFBDBDBD); // Dim text for hints
  static const errorRed = Color(0xFFEF5350); // Soft red for error messages
  static final borderGray = Color(0xFF2E7D32).withOpacity(0.2); // Subtle green border
  static final hintGray = Color(0xFFFFFFFF).withOpacity(0.38); // Hint text color
}

class JobsPage extends StatefulWidget {
  @override
  _JobsPageState createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> with SingleTickerProviderStateMixin {
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _jobDescriptionController = TextEditingController();
  final TextEditingController _jobLocationController = TextEditingController();
  final TextEditingController _jobSalaryController = TextEditingController();
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final List<String> categories = ['IT', 'Sales', 'Marketing', 'Engineering', 'Government'];
  String selectedCategory = 'IT';
  List<Map<String, dynamic>> jobListings = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
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
        'category': selectedCategory,
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'applicants': [],
      });
      _jobTitleController.clear();
      _jobDescriptionController.clear();
      _jobLocationController.clear();
      _jobSalaryController.clear();
      _fetchJobs();
      Navigator.of(context).pop();
    }
  }

  Future<void> _applyForJob(String jobId) async {
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'applicants': FieldValue.arrayUnion([userId]),
    });
    _fetchJobs();
  }

  void _showAddJobDialog() {
    String tempSelectedCategory = selectedCategory;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.darkBackground,
              title: Text('Add New Job', style: TextStyle(color: AppColors.textLight)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _jobTitleController,
                      decoration: InputDecoration(
                        labelText: 'Job Title',
                        labelStyle: TextStyle(color: AppColors.hintGray),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.borderGray),
                        ),
                      ),
                    ),
                    TextField(
                      controller: _jobDescriptionController,
                      decoration: InputDecoration(
                        labelText: 'Job Description',
                        labelStyle: TextStyle(color: AppColors.hintGray),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.borderGray),
                        ),
                      ),
                    ),
                    TextField(
                      controller: _jobLocationController,
                      decoration: InputDecoration(
                        labelText: 'Job Location',
                        labelStyle: TextStyle(color: AppColors.hintGray),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.borderGray),
                        ),
                      ),
                    ),
                    TextField(
                      controller: _jobSalaryController,
                      decoration: InputDecoration(
                        labelText: 'Salary',
                        labelStyle: TextStyle(color: AppColors.hintGray),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.borderGray),
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: tempSelectedCategory,
                      dropdownColor: AppColors.darkBackground,
                      style: TextStyle(color: AppColors.textLight),
                      onChanged: (String? newValue) {
                        setState(() {
                          tempSelectedCategory = newValue!;
                        });
                      },
                      items: categories.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppColors.textDim)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedCategory = tempSelectedCategory;
                    });
                    _addJob();
                  },
                  child: Text('Add Job', style: TextStyle(color: AppColors.primaryGreen)),
                ),
              ],
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: Text("Job Openings", style: TextStyle(color: AppColors.textLight)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.textLight,
          unselectedLabelColor: AppColors.textDim,
          indicatorColor: AppColors.primaryGreen,
          tabs: categories.map((category) => Tab(text: category)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: categories.map((category) {
          List<Map<String, dynamic>> filteredJobs = jobListings.where((job) => job['category'] == category).toList();
          return filteredJobs.isNotEmpty
              ? ListView.builder(
            itemCount: filteredJobs.length,
            itemBuilder: (context, index) {
              final job = filteredJobs[index];
              return _buildJobCard(job);
            },
          )
              : Center(child: Text("No jobs in $category", style: TextStyle(color: AppColors.textDim)));
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddJobDialog,
        backgroundColor: AppColors.primaryGreen,
        child: Icon(Icons.add, color: AppColors.textLight),
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
        color: Colors.grey[900],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(job['title'] ?? 'Title', style: TextStyle(color: AppColors.textLight)),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: job['hasApplied'] ? null : () => _applyForJob(job['id']),
                    child: Text(job['hasApplied'] ? 'Applied' : 'Apply', style: TextStyle(color: AppColors.primaryGreen)),
                  ),
                  Text('${job['applicantCount']} Applicants', style: TextStyle(color: AppColors.textDim)),
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
        backgroundColor: AppColors.darkBackground,
      ),
      backgroundColor: AppColors.darkBackground,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job['title'] ?? 'Job Title',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textLight),
            ),
            SizedBox(height: 16),
            Text(
              'Description: ${job['description'] ?? 'No Description'}',
              style: TextStyle(fontSize: 16, color: AppColors.textDim),
            ),
            SizedBox(height: 8),
            Text(
              'Location: ${job['location'] ?? 'Unknown Location'}',
              style: TextStyle(fontSize: 16, color: AppColors.textDim),
            ),
            SizedBox(height: 8),
            Text(
              'Salary: ${job['salary'] ?? 'Not specified'}',
              style: TextStyle(fontSize: 16, color: AppColors.textDim),
            ),
            SizedBox(height: 16),
            Text('${job['applicantCount']} Applicants', style: TextStyle(fontSize: 16, color: AppColors.textDim)),
          ],
        ),
      ),
    );
  }
}
