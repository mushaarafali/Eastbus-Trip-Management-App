<?php
use Illuminate\Support\Facades\Route;use App\Http\Controllers\Api\StaffAuthController;use App\Http\Controllers\Api\TripStaffController;
Route::get('/health',fn()=>['success'=>true,'service'=>'EastBus API','time'=>now()->toIso8601String()]);
Route::post('/staff/login',[StaffAuthController::class,'login']);
Route::middleware('staff.api')->prefix('staff')->group(function(){
 Route::get('/me',[StaffAuthController::class,'me']); Route::post('/logout',[StaffAuthController::class,'logout']); Route::get('/dashboard',[TripStaffController::class,'dashboard']); Route::get('/trips',[TripStaffController::class,'trips']);
 Route::post('/trips/{id}/start',[TripStaffController::class,'start']); Route::post('/trips/{id}/end',[TripStaffController::class,'end']); Route::post('/trips/{id}/location',[TripStaffController::class,'location']); Route::get('/trips/{id}/passengers',[TripStaffController::class,'passengers']); Route::post('/trips/{id}/emergency',[TripStaffController::class,'emergency']);
 Route::post('/tickets/verify',[TripStaffController::class,'verifyTicket']); Route::post('/tickets/check-in',[TripStaffController::class,'checkIn']); Route::get('/notifications',[TripStaffController::class,'notifications']);
});
