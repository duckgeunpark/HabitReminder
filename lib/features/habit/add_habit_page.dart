import 'package:flutter/material.dart';
import '../../data/habit_model.dart';
import '../../features/habit/habit_service.dart';
import 'habit_form_page.dart';

class AddHabitPage extends StatelessWidget {
  const AddHabitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return HabitFormPage(
      habit: null, // 새로 생성
      onSave: (Habit habit) async {
        final habitService = HabitService();
        await habitService.addHabit(habit);
      },
    );
  }
} 