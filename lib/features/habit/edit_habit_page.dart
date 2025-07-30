import 'package:flutter/material.dart';
import '../../data/habit_model.dart';
import '../../features/habit/habit_service.dart';
import 'habit_form_page.dart';

class EditHabitPage extends StatelessWidget {
  final Habit habit;

  const EditHabitPage({super.key, required this.habit});

  @override
  Widget build(BuildContext context) {
    return HabitFormPage(
      habit: habit, // 수정할 습관 전달
      onSave: (Habit updatedHabit) async {
        final habitService = HabitService();
        await habitService.updateHabit(updatedHabit);
      },
    );
  }
} 