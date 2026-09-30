<?php
namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FirebaseSyncService
{
    private function base(): string { return rtrim((string) env('FIREBASE_DATABASE_URL'), '/'); }
    private function url(string $path): string { return $this->base().'/'.trim($path,'/').'.json'; }
    public function set(string $path, array $data): bool {
        if ($this->base()==='') return false;
        try { $r=Http::timeout(8)->put($this->url($path),$data); if(!$r->successful()) Log::warning('Firebase set failed',['path'=>$path,'status'=>$r->status(),'body'=>$r->body()]); return $r->successful(); }
        catch(\Throwable $e){ Log::error('Firebase set exception',['path'=>$path,'message'=>$e->getMessage()]); return false; }
    }
    public function update(string $path, array $data): bool {
        if ($this->base()==='') return false;
        try { $r=Http::timeout(8)->patch($this->url($path),$data); if(!$r->successful()) Log::warning('Firebase update failed',['path'=>$path,'status'=>$r->status(),'body'=>$r->body()]); return $r->successful(); }
        catch(\Throwable $e){ Log::error('Firebase update exception',['path'=>$path,'message'=>$e->getMessage()]); return false; }
    }
    public function delete(string $path): bool {
        if ($this->base()==='') return false;
        try { return Http::timeout(8)->delete($this->url($path))->successful(); } catch(\Throwable $e){ return false; }
    }
}
